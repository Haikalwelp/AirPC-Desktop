pragma ComponentBehavior: Bound

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtWebEngine
import AirPCApiClient 1.0 as Backend
import "." as App

Item {
    id: root
    objectName: qsTr("Playtime")

    readonly property var apiClient: Backend.AirPCApiClient

    property var profile: ({})
    property var entitlements: root.apiClient.entitlements
    property var skus: []
    property int selectedSkuId: -1

    property bool profileReady: false
    property bool skuReady: false
    property bool isLoading: true
    property string pageError: ""

    property bool creatingSession: false
    property string paymentModalUrl: ""
    property bool paymentPageLoading: false
    property int activePurchaseId: 0

    property var receipt: ({})
    property bool hasReceipt: false
    property bool isPollingReceipt: false
    property int pollSecondsLeft: 0
    property string receiptMessage: ""

    readonly property var paymentDomains: [
        "adyen.com",
        "touchngo.com.my",
        "fpx.com.my",
        "maybank2u.com.my",
        "cimbclicks.com.my"
    ]

    readonly property var airpcDomains: [
        "airpc.co",
        "airpc.my",
        "localhost",
        "127.0.0.1"
    ]

    function updateLoadingState() {
        isLoading = !(profileReady && skuReady)
    }

    function formatPlaytime(seconds) {
        var total = Math.max(0, Number(seconds) || 0)
        var hours = Math.floor(total / 3600)
        var minutes = Math.floor((total % 3600) / 60)
        if (hours > 0 && minutes > 0) return hours + "h " + minutes + "m"
        if (hours > 0) return hours + "h"
        return minutes + "m"
    }

    function formatMoney(amountObj) {
        if (!amountObj || amountObj.value === undefined || amountObj.value === null) {
            return "MYR 0.00"
        }
        var code = amountObj.currency || "MYR"
        var value = (Number(amountObj.value) / 100.0).toFixed(2)
        return code + " " + value
    }

    function describeSku(sku) {
        if (!sku) return ""

        if (sku.sku_type === "voucher_pack") {
            var count = Number(sku.grant_voucher_count) || 0
            var duration = Number(sku.grant_voucher_duration_seconds) || 0
            return count + " voucher" + (count === 1 ? "" : "s") + " x " + formatPlaytime(duration)
        }

        if (sku.sku_type === "subscription_hours_pack") {
            var sec = Number(sku.grant_subscription_seconds || sku.playtime_seconds) || 0
            var days = Number(sku.subscription_period_days) || 30
            return formatPlaytime(sec) + " reusable within " + days + " day" + (days === 1 ? "" : "s")
        }

        var fallback = Number(sku.playtime_seconds || sku.grant_subscription_seconds) || 0
        return "Adds " + formatPlaytime(fallback)
    }

    function selectedSku() {
        for (var i = 0; i < skus.length; i++) {
            if (Number(skus[i].sku_id) === Number(selectedSkuId)) {
                return skus[i]
            }
        }
        return null
    }

    function sortedSubscriptionWindows() {
        var list = []
        if (entitlements && entitlements.subscriptions) {
            list = entitlements.subscriptions.slice(0)
            list.sort(function(a, b) {
                return new Date(a.period_end_at).getTime() - new Date(b.period_end_at).getTime()
            })
        }
        return list
    }

    function legacyCarryoverSeconds() {
        return Math.max(0, Number(profile.playtime_seconds) || 0)
    }

    function availableSeconds() {
        var windows = sortedSubscriptionWindows()
        if (windows.length > 0) {
            var total = legacyCarryoverSeconds()
            for (var i = 0; i < windows.length; i++) {
                total += Math.max(0, Number(windows[i].remaining_seconds) || 0)
            }
            return total
        }

        if (entitlements && entitlements.subscriptionSeconds !== undefined) {
            return Math.max(0, Number(entitlements.subscriptionSeconds) || 0)
        }

        if (profile.subscription_seconds !== undefined) {
            return Math.max(0, Number(profile.subscription_seconds) || 0)
        }

        return legacyCarryoverSeconds()
    }

    function openPaymentModal(sessionData) {
        var session = sessionData.session || ({})
        var sessionId = session.id || ""
        var sessionValue = session.sessionData || ""
        var clientKey = sessionData.client_key || ""
        var environment = sessionData.environment || "test"
        var purchaseId = Number(sessionData.purchase_id) || 0

        if (sessionId.length === 0 || sessionValue.length === 0 || clientKey.length === 0 || purchaseId <= 0) {
            pageError = qsTr("Invalid payment session payload")
            return
        }

        activePurchaseId = purchaseId
        hasReceipt = true
        receipt = {
            "purchase_id": purchaseId,
            "order_number": sessionData.order_number || "",
            "status": "PROCESSING",
            "amount": selectedSku() ? selectedSku().amount : ({ "currency": "MYR", "value": 0 })
        }
        receiptMessage = qsTr("Complete payment in the secure modal. Status will update automatically.")

        var baseUrl = root.apiClient.getWebBaseUrl()
        var query = [
            "session_id=" + encodeURIComponent(sessionId),
            "session_data=" + encodeURIComponent(sessionValue),
            "client_key=" + encodeURIComponent(clientKey),
            "environment=" + encodeURIComponent(environment),
            "purchase_id=" + encodeURIComponent(String(purchaseId))
        ]

        paymentModalUrl = baseUrl + "/pay/adyen?" + query.join("&")
        paymentPageLoading = true
        paymentDialog.open()
    }

    function isAllowedPaymentUrl(url) {
        var urlStr = url.toString().toLowerCase()

        for (var i = 0; i < paymentDomains.length; i++) {
            if (urlStr.indexOf(paymentDomains[i]) !== -1) {
                return true
            }
        }

        for (var j = 0; j < airpcDomains.length; j++) {
            if (urlStr.indexOf(airpcDomains[j]) !== -1) {
                return urlStr.indexOf("/pay/adyen") !== -1
            }
        }

        return false
    }

    function extractReturnPurchaseId(urlStr) {
        var match = urlStr.match(/\/pay\/adyen\/return\/(\d+)/)
        if (match && match[1]) {
            return Number(match[1]) || 0
        }
        return 0
    }

    function startReceiptPolling(purchaseId) {
        if (purchaseId <= 0) {
            return
        }

        activePurchaseId = purchaseId
        hasReceipt = true
        isPollingReceipt = true
        pollSecondsLeft = 60
        receiptMessage = qsTr("Waiting for payment confirmation...")
        root.apiClient.fetchBillingPurchase(purchaseId)
    }

    function stopReceiptPolling(message) {
        isPollingReceipt = false
        if (message && message.length > 0) {
            receiptMessage = message
        }
    }

    function handlePurchaseUpdate(purchaseMap) {
        if (!purchaseMap) {
            return
        }

        hasReceipt = true
        receipt = purchaseMap

        var status = String(purchaseMap.status || "").toUpperCase()
        if (status === "CONFIRMED") {
            stopReceiptPolling(qsTr("Payment confirmed. Balance updated."))
            root.apiClient.fetchProfile()
            root.apiClient.fetchEntitlements()
            return
        }

        if (status === "FAILED") {
            stopReceiptPolling(qsTr("Payment failed. Please try another payment method."))
            return
        }

        if (status === "CANCELLED") {
            stopReceiptPolling(qsTr("Payment was cancelled."))
            return
        }

        if (status === "PROCESSING" && !isPollingReceipt && activePurchaseId > 0) {
            startReceiptPolling(activePurchaseId)
        }
    }

    function refreshAll() {
        pageError = ""
        profileReady = false
        skuReady = false
        updateLoadingState()

        root.apiClient.fetchProfile()
        root.apiClient.fetchEntitlements()
        root.apiClient.fetchBillingSkus()
    }

    function startCheckout() {
        var sku = selectedSku()
        if (!sku) {
            pageError = qsTr("Please select a package")
            return
        }

        pageError = ""
        creatingSession = true

        var returnUrlBase = root.apiClient.getWebBaseUrl() + "/pay/adyen/return"
        root.apiClient.createAdyenSession(Number(sku.sku_id), returnUrlBase)
    }

    Component.onCompleted: {
        refreshAll()
    }

    Connections {
        target: root.apiClient

        function onProfileDataLoaded(profileMap) {
            root.profile = profileMap || ({})
            root.profileReady = true
            root.updateLoadingState()
        }

        function onProfileLoaded(playtimeSec, claimCnt, uname, mail) {
            if (root.profileReady) {
                return
            }

            root.profile = {
                "account_id": root.profile.account_id || 0,
                "username": uname || "",
                "email": mail || "",
                "subscription_seconds": root.profile.subscription_seconds || playtimeSec || 0,
                "playtime_seconds": playtimeSec || 0,
                "claim_count": claimCnt || 0,
                "available_vouchers": root.profile.available_vouchers || 0,
                "active_voucher": root.profile.active_voucher || null
            }

            root.profileReady = true
            root.updateLoadingState()
        }

        function onEntitlementsChanged() {
            root.entitlements = root.apiClient.entitlements
        }

        function onBillingSkusReceived(rows) {
            var filtered = []
            var list = rows || []
            for (var i = 0; i < list.length; i++) {
                var skuType = list[i].sku_type || ""
                if (skuType === "voucher_pack" || skuType === "subscription_hours_pack") {
                    filtered.push(list[i])
                }
            }

            filtered.sort(function(a, b) {
                var left = Number(a.sort_order) || 0
                var right = Number(b.sort_order) || 0
                return left - right
            })

            root.skus = filtered
            if (filtered.length > 0 && root.selectedSkuId <= 0) {
                root.selectedSkuId = Number(filtered[0].sku_id)
            }

            root.skuReady = true
            root.updateLoadingState()
        }

        function onBillingSkusFailed(error) {
            root.pageError = error || qsTr("Failed to load packages")
            root.skus = []
            root.skuReady = true
            root.updateLoadingState()
        }

        function onAdyenSessionCreated(sessionData) {
            root.creatingSession = false
            root.openPaymentModal(sessionData || ({}))
        }

        function onAdyenSessionFailed(error) {
            root.creatingSession = false
            root.pageError = error || qsTr("Failed to create payment session")
        }

        function onBillingPurchaseReceived(purchaseMap) {
            root.handlePurchaseUpdate(purchaseMap || ({}))
        }

        function onBillingPurchaseFailed(error) {
            if (!root.isPollingReceipt) {
                root.receiptMessage = error || qsTr("Failed to load receipt status")
            }
        }
    }

    Timer {
        id: receiptPollTimer
        interval: 2000
        repeat: true
        running: root.isPollingReceipt

        onTriggered: {
            if (root.activePurchaseId <= 0) {
                root.stopReceiptPolling("")
                return
            }

            root.pollSecondsLeft = Math.max(0, root.pollSecondsLeft - 2)
            if (root.pollSecondsLeft <= 0) {
                root.stopReceiptPolling(qsTr("Still processing. You can check again in a moment."))
                return
            }

            root.apiClient.fetchBillingPurchase(root.activePurchaseId)
        }
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: App.AirPCTheme.gradientStop1 }
            GradientStop { position: 0.33; color: App.AirPCTheme.gradientStop2 }
            GradientStop { position: 0.66; color: App.AirPCTheme.gradientStop3 }
            GradientStop { position: 1.0; color: App.AirPCTheme.gradientStop4 }
        }
    }

    Flickable {
        id: pageScroll
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: contentColumn.implicitHeight + 80

        Column {
            id: contentColumn
            width: Math.min(980, root.width - 32)
            anchors.horizontalCenter: parent.horizontalCenter
            y: 28
            spacing: 18

            Column {
                width: parent.width
                spacing: 6

                Text {
                    text: qsTr("Plans")
                    font.pixelSize: 32
                    font.weight: Font.Bold
                    font.family: App.AirPCTheme.fontFamily
                    color: App.AirPCTheme.textOnGradient
                }

                Text {
                    text: qsTr("Buy vouchers or subscription plans.")
                    font.pixelSize: 15
                    font.family: App.AirPCTheme.fontFamily
                    color: App.AirPCTheme.textOnGradientMuted
                }
            }

            Rectangle {
                id: balanceCard
                width: parent.width
                height: balanceCardContent.implicitHeight + 48
                radius: 16
                color: App.AirPCTheme.glassBackground
                border.color: App.AirPCTheme.glassBorder
                border.width: App.AirPCTheme.glassBorderWidth

                ColumnLayout {
                    id: balanceCardContent
                    x: 24
                    y: 24
                    width: parent.width - 48
                    spacing: 10

                    Text {
                        text: qsTr("Subscription Balance")
                        font.pixelSize: 18
                        font.weight: Font.DemiBold
                        font.family: App.AirPCTheme.fontFamily
                        color: App.AirPCTheme.textPrimary
                    }

                    Text {
                        text: root.formatPlaytime(root.availableSeconds())
                        font.pixelSize: 44
                        font.weight: Font.Black
                        font.family: App.AirPCTheme.fontFamily
                        color: App.AirPCTheme.primary
                    }

                    Text {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        text: root.sortedSubscriptionWindows().length > 0
                              ? qsTr("Available across active period(s), including carry-over where applicable.")
                              : qsTr("Balance updates after payment confirmation.")
                        font.pixelSize: 13
                        font.family: App.AirPCTheme.fontFamily
                        color: App.AirPCTheme.textMuted
                    }
                }
            }

            Rectangle {
                id: skuCard
                width: parent.width
                height: skuCardContent.implicitHeight + 48
                radius: 16
                color: App.AirPCTheme.glassBackground
                border.color: App.AirPCTheme.glassBorder
                border.width: App.AirPCTheme.glassBorderWidth

                ColumnLayout {
                    id: skuCardContent
                    x: 24
                    y: 24
                    width: parent.width - 48
                    spacing: 14

                    Text {
                        text: qsTr("Select a Package")
                        font.pixelSize: 18
                        font.weight: Font.DemiBold
                        font.family: App.AirPCTheme.fontFamily
                        color: App.AirPCTheme.textPrimary
                    }

                    Flow {
                        id: skuFlow
                        Layout.fillWidth: true
                        spacing: 10

                        Repeater {
                            model: root.skus
                            delegate: Button {
                                id: skuButton
                                required property var modelData
                                width: skuFlow.width < 700 ? skuFlow.width : Math.floor((skuFlow.width - 20) / 3)
                                height: 110

                                readonly property bool selected: Number(modelData.sku_id) === Number(root.selectedSkuId)

                                onClicked: {
                                    root.selectedSkuId = Number(modelData.sku_id)
                                }

                                background: Rectangle {
                                    radius: 14
                                    color: Qt.rgba(255, 255, 255, 0.28)
                                    border.width: skuButton.selected ? 2 : 1
                                    border.color: skuButton.selected ? App.AirPCTheme.primary : Qt.rgba(69/255, 69/255, 69/255, 0.16)
                                }

                                contentItem: Column {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 6

                                    Row {
                                        width: parent.width
                                        spacing: 8

                                        Text {
                                            text: skuButton.modelData.label || qsTr("Plan")
                                            font.pixelSize: 15
                                            font.weight: Font.Bold
                                            font.family: App.AirPCTheme.fontFamily
                                            color: App.AirPCTheme.textPrimary
                                        }

                                        Item { width: 1; height: 1 }
                                    }

                                    Text {
                                        text: root.formatMoney(skuButton.modelData.amount)
                                        font.pixelSize: 16
                                        font.weight: Font.Black
                                        font.family: App.AirPCTheme.fontFamily
                                        color: App.AirPCTheme.primary
                                    }

                                    Text {
                                        width: parent.width
                                        wrapMode: Text.WordWrap
                                        text: root.describeSku(skuButton.modelData)
                                        font.pixelSize: 12
                                        font.family: App.AirPCTheme.fontFamily
                                        color: App.AirPCTheme.textMuted
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: checkoutCard
                width: parent.width
                height: checkoutCardContent.implicitHeight + 48
                radius: 16
                color: App.AirPCTheme.glassBackground
                border.color: App.AirPCTheme.glassBorder
                border.width: App.AirPCTheme.glassBorderWidth

                ColumnLayout {
                    id: checkoutCardContent
                    x: 24
                    y: 24
                    width: parent.width - 48
                    spacing: 12

                    Text {
                        text: qsTr("Checkout")
                        font.pixelSize: 18
                        font.weight: Font.DemiBold
                        font.family: App.AirPCTheme.fontFamily
                        color: App.AirPCTheme.textPrimary
                    }

                    Rectangle {
                        id: checkoutSummaryBox
                        Layout.fillWidth: true
                        Layout.preferredHeight: checkoutSummaryContent.implicitHeight + 28
                        radius: 12
                        color: Qt.rgba(255, 255, 255, 0.24)
                        border.color: Qt.rgba(255, 255, 255, 0.15)
                        border.width: 1

                        ColumnLayout {
                            id: checkoutSummaryContent
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: qsTr("Package")
                                    font.pixelSize: 13
                                    font.family: App.AirPCTheme.fontFamily
                                    color: App.AirPCTheme.textMuted
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: root.selectedSku() ? (root.selectedSku().label || "-") : "-"
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    font.family: App.AirPCTheme.fontFamily
                                    color: App.AirPCTheme.textPrimary
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: qsTr("Includes")
                                    font.pixelSize: 13
                                    font.family: App.AirPCTheme.fontFamily
                                    color: App.AirPCTheme.textMuted
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: root.selectedSku() ? root.describeSku(root.selectedSku()) : "-"
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    font.family: App.AirPCTheme.fontFamily
                                    color: App.AirPCTheme.textPrimary
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: qsTr("Total")
                                    font.pixelSize: 13
                                    font.family: App.AirPCTheme.fontFamily
                                    color: App.AirPCTheme.textMuted
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: root.selectedSku() ? root.formatMoney(root.selectedSku().amount) : "-"
                                    font.pixelSize: 15
                                    font.weight: Font.Black
                                    font.family: App.AirPCTheme.fontFamily
                                    color: App.AirPCTheme.primary
                                }
                            }
                        }
                    }

                    App.PrimaryButton {
                        Layout.fillWidth: true
                        text: root.creatingSession ? qsTr("Preparing secure checkout...") : qsTr("Open Secure Checkout")
                        enabled: !root.creatingSession && root.selectedSku() !== null
                        onClicked: root.startCheckout()
                    }

                    Text {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: qsTr("Only the Adyen payment form opens in modal. Plans and receipt stay native in desktop.")
                        font.pixelSize: 12
                        font.family: App.AirPCTheme.fontFamily
                        color: App.AirPCTheme.textMuted
                    }
                }
            }

            Rectangle {
                visible: root.hasReceipt
                width: parent.width
                height: receiptCardContent.implicitHeight + 48
                radius: 16
                color: App.AirPCTheme.glassBackground
                border.color: App.AirPCTheme.glassBorder
                border.width: App.AirPCTheme.glassBorderWidth

                ColumnLayout {
                    id: receiptCardContent
                    x: 24
                    y: 24
                    width: parent.width - 48
                    spacing: 12

                    Text {
                        text: qsTr("Receipt")
                        font.pixelSize: 18
                        font.weight: Font.DemiBold
                        font.family: App.AirPCTheme.fontFamily
                        color: App.AirPCTheme.textPrimary
                    }

                    Rectangle {
                        Layout.preferredWidth: 130
                        Layout.preferredHeight: 30
                        radius: 15
                        color: {
                            var status = String(root.receipt.status || "PROCESSING").toUpperCase()
                            if (status === "CONFIRMED") return Qt.rgba(20/255, 83/255, 45/255, 0.14)
                            if (status === "PROCESSING") return Qt.rgba(31/255, 21/255, 167/255, 0.12)
                            return Qt.rgba(249/255, 65/255, 65/255, 0.12)
                        }
                        border.width: 1
                        border.color: {
                            var status = String(root.receipt.status || "PROCESSING").toUpperCase()
                            if (status === "CONFIRMED") return Qt.rgba(20/255, 83/255, 45/255, 0.25)
                            if (status === "PROCESSING") return Qt.rgba(31/255, 21/255, 167/255, 0.25)
                            return Qt.rgba(249/255, 65/255, 65/255, 0.25)
                        }

                        Text {
                            anchors.centerIn: parent
                            text: String(root.receipt.status || "PROCESSING").toUpperCase()
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            font.family: App.AirPCTheme.fontFamily
                            color: {
                                var status = String(root.receipt.status || "PROCESSING").toUpperCase()
                                if (status === "CONFIRMED") return "#14532d"
                                if (status === "PROCESSING") return "#1F15A7"
                                return "#F94141"
                            }
                        }
                    }

                    Rectangle {
                        id: receiptSummaryBox
                        Layout.fillWidth: true
                        Layout.preferredHeight: receiptSummaryContent.implicitHeight + 28
                        radius: 12
                        color: Qt.rgba(255, 255, 255, 0.24)
                        border.color: Qt.rgba(255, 255, 255, 0.15)
                        border.width: 1

                        ColumnLayout {
                            id: receiptSummaryContent
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: qsTr("Order")
                                    font.pixelSize: 13
                                    font.family: App.AirPCTheme.fontFamily
                                    color: App.AirPCTheme.textMuted
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: root.receipt.order_number || "-"
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    font.family: App.AirPCTheme.fontFamily
                                    color: App.AirPCTheme.textPrimary
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: qsTr("Amount")
                                    font.pixelSize: 13
                                    font.family: App.AirPCTheme.fontFamily
                                    color: App.AirPCTheme.textMuted
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: root.formatMoney(root.receipt.amount)
                                    font.pixelSize: 14
                                    font.weight: Font.Black
                                    font.family: App.AirPCTheme.fontFamily
                                    color: App.AirPCTheme.primary
                                }
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: root.isPollingReceipt
                              ? (root.receiptMessage + " (" + root.pollSecondsLeft + "s)")
                              : root.receiptMessage
                        font.pixelSize: 12
                        font.family: App.AirPCTheme.fontFamily
                        color: App.AirPCTheme.textMuted
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        App.PrimaryButton {
                            Layout.fillWidth: true
                            text: qsTr("Check Status")
                            enabled: root.activePurchaseId > 0 && !root.isPollingReceipt
                            onClicked: {
                                root.receiptMessage = qsTr("Refreshing receipt status...")
                                root.apiClient.fetchBillingPurchase(root.activePurchaseId)
                            }
                        }

                        Button {
                            Layout.fillWidth: true
                            text: qsTr("Buy Another Plan")
                            enabled: !root.creatingSession
                            onClicked: {
                                root.pageError = ""
                            }
                        }
                    }
                }
            }

            Text {
                visible: root.pageError.length > 0
                width: parent.width
                wrapMode: Text.WordWrap
                text: root.pageError
                font.pixelSize: 13
                font.family: App.AirPCTheme.fontFamily
                color: "#F94141"
            }

            Item {
                width: parent.width
                height: 24
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: root.isLoading
        color: "transparent"

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 14

            BusyIndicator {
                Layout.alignment: Qt.AlignHCenter
                running: root.isLoading
                palette.dark: App.AirPCTheme.textOnGradient
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Loading purchase options...")
                font.pixelSize: 14
                font.family: App.AirPCTheme.fontFamily
                color: App.AirPCTheme.textOnGradient
            }
        }
    }

    Dialog {
        id: paymentDialog
        modal: true
        focus: true
        anchors.centerIn: parent
        width: Math.min(root.width * 0.92, 980)
        height: Math.min(root.height * 0.90, 760)
        padding: 0
        closePolicy: Popup.CloseOnEscape

        onClosed: {
            paymentWebView.url = "about:blank"
        }

        background: Rectangle {
            radius: 16
            color: Qt.rgba(16/255, 20/255, 35/255, 0.96)
            border.color: Qt.rgba(1, 1, 1, 0.20)
            border.width: 1
        }

        contentItem: ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                color: Qt.rgba(1, 1, 1, 0.12)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 10
                    spacing: 8

                    Text {
                        text: qsTr("Secure Payment")
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                        font.family: App.AirPCTheme.fontFamily
                        color: "#FFFFFF"
                    }

                    Item { Layout.fillWidth: true }

                    ToolButton {
                        text: "\u2715"
                        font.pixelSize: 16
                        onClicked: paymentDialog.close()
                    }
                }
            }

            Item {
                id: paymentViewport
                Layout.fillWidth: true
                Layout.fillHeight: true

                WebEngineView {
                    id: paymentWebView
                    anchors.fill: paymentViewport
                    visible: paymentDialog.visible
                    backgroundColor: "transparent"

                    settings.javascriptEnabled: true
                    settings.localStorageEnabled: true
                    settings.pluginsEnabled: true

                    onLoadingChanged: function(loadRequest) {
                        if (loadRequest.status === WebEngineView.LoadStartedStatus) {
                            root.paymentPageLoading = true
                        } else if (loadRequest.status === WebEngineView.LoadSucceededStatus) {
                            root.paymentPageLoading = false
                        } else if (loadRequest.status === WebEngineView.LoadFailedStatus) {
                            root.paymentPageLoading = false
                            root.pageError = loadRequest.errorString || qsTr("Failed to load payment page")
                        }
                    }

                    onUrlChanged: {
                        var current = paymentWebView.url.toString()
                        var lower = current.toLowerCase()

                        var returnId = root.extractReturnPurchaseId(lower)
                        if (returnId > 0) {
                            paymentDialog.close()
                            root.startReceiptPolling(returnId)
                            return
                        }

                        if (lower.indexOf("/login") !== -1 || lower.indexOf("/auth") !== -1) {
                            paymentDialog.close()
                            root.apiClient.logout()
                        }
                    }

                    onNewWindowRequested: function(request) {
                        if (root.isAllowedPaymentUrl(request.requestedUrl)) {
                            request.openIn(paymentWebView)
                        }
                    }

                    onNavigationRequested: function(request) {
                        if (root.isAllowedPaymentUrl(request.url)) {
                            request.accept()
                        } else {
                            request.reject()
                        }
                    }

                    onRenderProcessTerminated: function(terminationStatus, exitCode) {
                        root.pageError = qsTr("Payment page crashed. Please retry.")
                        console.error("Payment WebView terminated:", terminationStatus, exitCode)
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    visible: root.paymentPageLoading
                    color: Qt.rgba(0, 0, 0, 0.30)

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 10

                        BusyIndicator {
                            Layout.alignment: Qt.AlignHCenter
                            running: root.paymentPageLoading
                            palette.dark: "#FFFFFF"
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: qsTr("Loading secure payment...")
                            font.pixelSize: 13
                            font.family: App.AirPCTheme.fontFamily
                            color: "#FFFFFF"
                        }
                    }
                }
            }
        }

        onVisibleChanged: {
            if (visible && root.paymentModalUrl.length > 0) {
                paymentWebView.url = root.paymentModalUrl
            }
        }
    }
}
