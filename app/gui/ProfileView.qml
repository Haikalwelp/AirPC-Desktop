pragma ComponentBehavior: Bound

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import AirPCApiClient 1.0 as Backend
import "." as App

FocusScope {
    id: root
    objectName: qsTr("Profile")

    readonly property var apiClient: Backend.AirPCApiClient

    property var profile: ({})
    property var entitlements: root.apiClient.entitlements

    property var claimHistory: []
    property var purchases: []
    property var subscriptionWindows: []

    property int purchaseCount: 0
    property int purchasePage: 1
    property bool hasMorePurchases: false
    property bool purchaseAppendMode: false

    property bool isLoading: true
    property bool isLoadingPurchases: false
    property bool isClaiming: false

    property string activeTab: "claims"   // claims | purchases
    property string claimError: ""
    property string purchaseError: ""

    readonly property bool isMobile: width < 640
    readonly property string username: profile.username ? profile.username : ""
    readonly property string email: profile.email ? profile.email : ""
    readonly property int accountId: profile.account_id ? profile.account_id : 0
    readonly property int claimCount: profile.claim_count ? profile.claim_count : 0
    readonly property int availableVouchers: profile.available_vouchers ? profile.available_vouchers : 0
    readonly property var activeVoucher: profile.active_voucher ? profile.active_voucher : null

    function formatPlaytime(seconds) {
        var total = Math.max(0, seconds || 0)
        var hours = Math.floor(total / 3600)
        var minutes = Math.floor((total % 3600) / 60)
        if (hours > 0) {
            return hours + "h " + minutes + "m"
        }
        return minutes + "m"
    }

    function formatDate(dateStr) {
        if (!dateStr || dateStr.length === 0) {
            return "-"
        }
        var d = new Date(dateStr)
        if (isNaN(d.getTime())) {
            return "-"
        }
        var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        return months[d.getMonth()] + " " + d.getDate() + ", " + d.getFullYear()
    }

    function formatDateTime(dateStr) {
        if (!dateStr || dateStr.length === 0) {
            return "-"
        }
        var d = new Date(dateStr)
        if (isNaN(d.getTime())) {
            return "-"
        }
        var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        var hours = d.getHours()
        var suffix = hours >= 12 ? "PM" : "AM"
        hours = hours % 12
        if (hours === 0) {
            hours = 12
        }
        var minutes = d.getMinutes()
        var minuteText = minutes < 10 ? ("0" + minutes) : minutes.toString()
        return months[d.getMonth()] + " " + d.getDate() + ", " + d.getFullYear() + " " + hours + ":" + minuteText + " " + suffix
    }

    function formatMoney(currency, valueCents) {
        var code = currency && currency.length > 0 ? currency : "MYR"
        var value = ((valueCents || 0) / 100.0).toFixed(2)
        return code + " " + value
    }

    function getStatusLabel(status) {
        if (status === "PROCESSING") return "Processing"
        if (status === "CONFIRMED") return "Confirmed"
        if (status === "FAILED") return "Failed"
        if (status === "CANCELLED") return "Cancelled"
        return status || "Unknown"
    }

    function getStatusColor(status) {
        if (status === "CONFIRMED") return "#0F6B45"
        if (status === "PROCESSING") return "#8A5A00"
        return "#9A1E1E"
    }

    function getStatusBg(status) {
        if (status === "CONFIRMED") return Qt.rgba(15/255, 107/255, 69/255, 0.14)
        if (status === "PROCESSING") return Qt.rgba(138/255, 90/255, 0/255, 0.14)
        return Qt.rgba(154/255, 30/255, 30/255, 0.14)
    }

    function getPurchaseTitle(purchase) {
        if (purchase.sku_label && purchase.sku_label.trim().length > 0) {
            return purchase.sku_label
        }
        if (purchase.sku_type === "voucher_pack") {
            return "Voucher Purchase"
        }
        if (purchase.sku_type === "subscription_hours_pack") {
            return "Subscription Purchase"
        }
        return "Purchase"
    }

    function getPurchasePeriodLabel(purchase) {
        if (purchase.subscription_period_days && purchase.subscription_period_days > 0) {
            var days = purchase.subscription_period_days
            return "Period: " + days + " day" + (days === 1 ? "" : "s")
        }
        if (purchase.sku_type === "playtime_pack") {
            return "Legacy playtime (no period)"
        }
        return ""
    }

    function syncSubscriptionWindows() {
        var list = []
        if (entitlements && entitlements.subscriptions) {
            list = entitlements.subscriptions.slice(0)
            list.sort(function(a, b) {
                var aTime = new Date(a.period_end_at).getTime()
                var bTime = new Date(b.period_end_at).getTime()
                return aTime - bTime
            })
        }
        subscriptionWindows = list
    }

    function hasSubscriptionWindows() {
        return subscriptionWindows.length > 0
    }

    function activeSubscriptionSeconds() {
        var total = 0
        for (var i = 0; i < subscriptionWindows.length; i++) {
            total += Math.max(0, subscriptionWindows[i].remaining_seconds || 0)
        }
        return total
    }

    function legacyCarryoverSeconds() {
        return Math.max(0, profile.playtime_seconds || 0)
    }

    function availableSeconds() {
        if (hasSubscriptionWindows()) {
            return activeSubscriptionSeconds() + legacyCarryoverSeconds()
        }
        if (entitlements && entitlements.subscriptionSeconds !== undefined) {
            return entitlements.subscriptionSeconds || 0
        }
        if (profile.subscription_seconds !== undefined) {
            return profile.subscription_seconds || 0
        }
        if (profile.playtime_seconds !== undefined) {
            return profile.playtime_seconds || 0
        }
        return 0
    }

    function isLegacyPlaytimeOnly() {
        return !hasSubscriptionWindows() && legacyCarryoverSeconds() > 0
    }

    function refreshAll() {
        root.apiClient.fetchProfile()
        root.apiClient.fetchEntitlements()
        root.apiClient.fetchClaimHistory()
        purchaseAppendMode = false
        isLoadingPurchases = true
        root.apiClient.fetchBillingPurchases(1, 10)
    }

    Component.onCompleted: {
        refreshAll()
    }

    Connections {
        target: root.apiClient

        function onProfileLoaded(playtimeSec, claimCnt, uname, mail) {
            // Backward-compatible fallback while richer profile signal is propagating.
            root.profile = {
                account_id: root.profile.account_id || 0,
                username: uname || "",
                email: mail || "",
                subscription_seconds: root.profile.subscription_seconds || playtimeSec || 0,
                playtime_seconds: playtimeSec || 0,
                claim_count: claimCnt || 0,
                available_vouchers: root.profile.available_vouchers || 0,
                active_voucher: root.profile.active_voucher || null
            }
            root.isLoading = false
        }

        function onProfileDataLoaded(profileMap) {
            root.profile = profileMap || ({})
            root.isLoading = false
        }

        function onEntitlementsChanged() {
            root.syncSubscriptionWindows()
        }

        function onClaimHistoryReceived(claims) {
            root.claimHistory = claims || []
        }

        function onBillingPurchasesReceived(rows, count, page, hasMore) {
            if (root.purchaseAppendMode) {
                root.purchases = root.purchases.concat(rows || [])
            } else {
                root.purchases = rows || []
            }
            root.purchaseCount = count || root.purchases.length
            root.purchasePage = page || 1
            root.hasMorePurchases = hasMore === true
            root.purchaseError = ""
            root.isLoadingPurchases = false
        }

        function onBillingPurchasesFailed(error) {
            root.purchaseError = error || "Failed to load purchases"
            root.isLoadingPurchases = false
        }

        function onClaimSucceeded(granted, total) {
            root.isClaiming = false
            root.claimError = ""
            orderInput.text = ""
            root.refreshAll()
        }

        function onClaimFailed(error) {
            root.isClaiming = false
            root.claimError = error || "Failed to redeem order"
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

        Rectangle {
            anchors.fill: parent
            rotation: -45
            scale: 1.5
            transformOrigin: Item.Center
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(222/255, 209/255, 198/255, 0.25) }
                GradientStop { position: 0.5; color: "transparent" }
                GradientStop { position: 1.0; color: Qt.rgba(15/255, 45/255, 77/255, 0.25) }
            }
        }
    }

    Item {
        anchors.fill: parent
        visible: root.isLoading

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 16

            BusyIndicator {
                Layout.alignment: Qt.AlignHCenter
                running: root.isLoading
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Fetching your profile...")
                font.pixelSize: 14
                font.family: App.AirPCTheme.fontFamily
                color: App.AirPCTheme.textOnGradient
            }
        }
    }

    ScrollView {
        anchors.fill: parent
        visible: !root.isLoading
        clip: true
        contentWidth: availableWidth

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
            contentItem: Rectangle {
                implicitWidth: 6
                radius: 3
                color: Qt.rgba(1, 1, 1, 0.2)
            }
        }
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        ColumnLayout {
            width: Math.min(parent.width, 900)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 24

            Item { Layout.preferredHeight: root.isMobile ? 24 : 40 }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: root.isMobile ? 16 : App.AirPCTheme.contentPaddingH
                Layout.rightMargin: root.isMobile ? 16 : App.AirPCTheme.contentPaddingH
                spacing: 8

                Text {
                    text: qsTr("User Profile")
                    font.pixelSize: root.isMobile ? 26 : App.AirPCTheme.pageTitleSize
                    font.weight: Font.Bold
                    font.family: App.AirPCTheme.fontFamily
                    color: App.AirPCTheme.textOnGradient
                }

                Text {
                    text: qsTr("Manage your account, vouchers, and purchase history")
                    font.pixelSize: root.isMobile ? 14 : App.AirPCTheme.pageSubtitleSize
                    font.family: App.AirPCTheme.fontFamily
                    color: App.AirPCTheme.textOnGradientMuted
                }
            }

            GridLayout {
                Layout.fillWidth: true
                Layout.leftMargin: root.isMobile ? 16 : App.AirPCTheme.contentPaddingH
                Layout.rightMargin: root.isMobile ? 16 : App.AirPCTheme.contentPaddingH
                columns: root.width >= 768 ? 2 : 1
                rowSpacing: 24
                columnSpacing: 24

                // Profile card
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: profileCardContent.implicitHeight + App.AirPCTheme.glassPadding * 2
                    color: App.AirPCTheme.glassBackground
                    radius: App.AirPCTheme.glassRadius
                    border.color: App.AirPCTheme.glassBorder
                    border.width: App.AirPCTheme.glassBorderWidth

                    ColumnLayout {
                        id: profileCardContent
                        anchors.fill: parent
                        anchors.margins: root.isMobile ? 20 : App.AirPCTheme.glassPadding
                        spacing: 20

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: root.isMobile ? 16 : 20

                            Rectangle {
                                implicitWidth: root.isMobile ? 52 : App.AirPCTheme.avatarSize
                                implicitHeight: implicitWidth
                                radius: width / 2
                                color: App.AirPCTheme.primary

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.topMargin: 4
                                    z: -1
                                    radius: parent.radius
                                    color: App.AirPCTheme.primaryShadow
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: root.username.length > 0 ? root.username.charAt(0).toUpperCase() : "U"
                                    font.pixelSize: root.isMobile ? 20 : App.AirPCTheme.avatarFontSize
                                    font.weight: Font.Bold
                                    font.family: App.AirPCTheme.fontFamily
                                    color: App.AirPCTheme.textOnPrimary
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    text: root.username.length > 0 ? root.username : qsTr("User")
                                    font.pixelSize: root.isMobile ? 18 : 22
                                    font.weight: Font.Bold
                                    font.family: App.AirPCTheme.fontFamily
                                    color: App.AirPCTheme.textPrimary
                                }

                                Text {
                                    text: root.email
                                    font.pixelSize: 14
                                    font.family: App.AirPCTheme.fontFamily
                                    color: App.AirPCTheme.textMuted
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 16

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 70
                                color: App.AirPCTheme.glassInner
                                radius: App.AirPCTheme.glassInnerRadius

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 4

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: qsTr("Account ID")
                                        font.pixelSize: 12
                                        font.letterSpacing: 0.5
                                        font.family: App.AirPCTheme.fontFamily
                                        color: App.AirPCTheme.textSecondary
                                    }

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: "#" + root.accountId
                                        font.pixelSize: 16
                                        font.weight: Font.DemiBold
                                        font.family: App.AirPCTheme.fontFamily
                                        color: App.AirPCTheme.textPrimary
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 70
                                color: App.AirPCTheme.glassInner
                                radius: App.AirPCTheme.glassInnerRadius

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 4

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: qsTr("Total Claims")
                                        font.pixelSize: 12
                                        font.letterSpacing: 0.5
                                        font.family: App.AirPCTheme.fontFamily
                                        color: App.AirPCTheme.textSecondary
                                    }

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: root.claimCount.toString()
                                        font.pixelSize: 16
                                        font.weight: Font.DemiBold
                                        font.family: App.AirPCTheme.fontFamily
                                        color: App.AirPCTheme.textPrimary
                                    }
                                }
                            }
                        }
                    }
                }

                // Subscription balance card
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: subscriptionCardContent.implicitHeight + App.AirPCTheme.glassPadding * 2
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(233/255, 69/255, 96/255, 0.10) }
                        GradientStop { position: 1.0; color: App.AirPCTheme.glassBackground }
                    }
                    radius: App.AirPCTheme.glassRadius
                    border.color: App.AirPCTheme.glassBorder
                    border.width: App.AirPCTheme.glassBorderWidth

                    ColumnLayout {
                        id: subscriptionCardContent
                        anchors.fill: parent
                        anchors.margins: root.isMobile ? 20 : App.AirPCTheme.glassPadding
                        spacing: 12

                        Text {
                            text: qsTr("Subscription Balance")
                            font.pixelSize: App.AirPCTheme.cardTitleSize
                            font.weight: Font.DemiBold
                            font.family: App.AirPCTheme.fontFamily
                            color: App.AirPCTheme.textPrimary
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: root.formatPlaytime(root.availableSeconds())
                                font.pixelSize: root.isMobile ? 36 : 48
                                font.weight: Font.ExtraBold
                                font.family: App.AirPCTheme.fontFamily
                                color: App.AirPCTheme.primary
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: root.hasSubscriptionWindows() && root.legacyCarryoverSeconds() > 0
                                    ? qsTr("Total available (subscription + legacy carry-over)")
                                    : (root.hasSubscriptionWindows()
                                        ? qsTr("Available across active period(s)")
                                        : qsTr("Available"))
                                font.pixelSize: 14
                                font.family: App.AirPCTheme.fontFamily
                                color: App.AirPCTheme.textSecondary
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                            }

                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.topMargin: 8
                                visible: root.hasSubscriptionWindows()
                                radius: 999
                                color: Qt.rgba(138/255, 28/255, 92/255, 0.12)
                                implicitHeight: 24
                                implicitWidth: badgeText.implicitWidth + 20

                                Text {
                                    id: badgeText
                                    anchors.centerIn: parent
                                    text: qsTr("Period-based")
                                    font.pixelSize: 12
                                    font.weight: Font.Bold
                                    font.letterSpacing: 0.3
                                    font.family: App.AirPCTheme.fontFamily
                                    color: App.AirPCTheme.primary
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                visible: root.hasSubscriptionWindows()
                                spacing: 2

                                Text {
                                    Layout.fillWidth: true
                                    text: qsTr("Next period ends ") + root.formatDateTime(root.subscriptionWindows.length > 0 ? root.subscriptionWindows[0].period_end_at : "")
                                    font.pixelSize: 13
                                    font.family: App.AirPCTheme.fontFamily
                                    color: App.AirPCTheme.textMuted
                                    wrapMode: Text.Wrap
                                }

                                Repeater {
                                    model: Math.min(2, root.subscriptionWindows.length)

                                    Text {
                                        required property int index
                                        Layout.fillWidth: true
                                        text: ((root.subscriptionWindows[index].label || ("Subscription #" + root.subscriptionWindows[index].subscription_instance_id))
                                               + ": " + root.formatPlaytime(root.subscriptionWindows[index].remaining_seconds)
                                               + qsTr(" left until ") + root.formatDateTime(root.subscriptionWindows[index].period_end_at))
                                        font.pixelSize: 13
                                        font.family: App.AirPCTheme.fontFamily
                                        color: App.AirPCTheme.textMuted
                                        wrapMode: Text.Wrap
                                    }
                                }

                                Text {
                                    visible: root.subscriptionWindows.length > 2
                                    text: "+" + (root.subscriptionWindows.length - 2) + qsTr(" more subscription period(s)")
                                    font.pixelSize: 13
                                    font.family: App.AirPCTheme.fontFamily
                                    color: App.AirPCTheme.textMuted
                                }

                                Text {
                                    visible: root.legacyCarryoverSeconds() > 0
                                    text: qsTr("Includes ") + root.formatPlaytime(root.legacyCarryoverSeconds()) + qsTr(" legacy carry-over.")
                                    font.pixelSize: 13
                                    font.family: App.AirPCTheme.fontFamily
                                    color: App.AirPCTheme.textMuted
                                    wrapMode: Text.Wrap
                                }
                            }

                            Text {
                                visible: !root.hasSubscriptionWindows() && root.isLegacyPlaytimeOnly()
                                Layout.fillWidth: true
                                text: qsTr("Legacy playtime balance with no period limit.")
                                font.pixelSize: 13
                                font.family: App.AirPCTheme.fontFamily
                                color: App.AirPCTheme.textMuted
                                wrapMode: Text.Wrap
                            }
                        }
                    }
                }

                // Voucher card
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: voucherCardContent.implicitHeight + App.AirPCTheme.glassPadding * 2
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(23/255, 72/255, 113/255, 0.12) }
                        GradientStop { position: 1.0; color: App.AirPCTheme.glassBackground }
                    }
                    radius: App.AirPCTheme.glassRadius
                    border.color: App.AirPCTheme.glassBorder
                    border.width: App.AirPCTheme.glassBorderWidth

                    ColumnLayout {
                        id: voucherCardContent
                        anchors.fill: parent
                        anchors.margins: root.isMobile ? 20 : App.AirPCTheme.glassPadding
                        spacing: 10

                        Text {
                            text: qsTr("Available Vouchers")
                            font.pixelSize: App.AirPCTheme.cardTitleSize
                            font.weight: Font.DemiBold
                            font.family: App.AirPCTheme.fontFamily
                            color: App.AirPCTheme.textPrimary
                        }

                        Text {
                            text: root.availableVouchers.toString()
                            font.pixelSize: 44
                            font.weight: Font.ExtraBold
                            font.family: App.AirPCTheme.fontFamily
                            color: "#174871"
                        }

                        Rectangle {
                            visible: root.activeVoucher !== null
                            radius: 999
                            color: Qt.rgba(23/255, 72/255, 113/255, 0.12)
                            implicitHeight: 24
                            implicitWidth: activeVoucherBadge.implicitWidth + 20

                            Text {
                                id: activeVoucherBadge
                                anchors.centerIn: parent
                                text: qsTr("Window Active")
                                font.pixelSize: 12
                                font.weight: Font.Bold
                                font.family: App.AirPCTheme.fontFamily
                                color: "#174871"
                            }
                        }

                        Text {
                            visible: root.activeVoucher !== null
                            Layout.fillWidth: true
                            text: qsTr("Locked to ") + (root.activeVoucher && (root.activeVoucher.computer_name || root.activeVoucher.computer_uuid) ? (root.activeVoucher.computer_name || root.activeVoucher.computer_uuid) : "-")
                            font.pixelSize: 13
                            font.family: App.AirPCTheme.fontFamily
                            color: App.AirPCTheme.textMuted
                            wrapMode: Text.Wrap
                        }

                        Text {
                            visible: root.activeVoucher !== null
                            Layout.fillWidth: true
                            text: qsTr("Ends ") + root.formatDateTime(root.activeVoucher ? root.activeVoucher.ends_at : "")
                            font.pixelSize: 13
                            font.family: App.AirPCTheme.fontFamily
                            color: App.AirPCTheme.textMuted
                            wrapMode: Text.Wrap
                        }

                        Text {
                            visible: root.activeVoucher === null
                            Layout.fillWidth: true
                            text: qsTr("No active voucher window right now.")
                            font.pixelSize: 13
                            font.family: App.AirPCTheme.fontFamily
                            color: App.AirPCTheme.textMuted
                            wrapMode: Text.Wrap
                        }
                    }
                }

                // Claim card
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: claimCardContent.implicitHeight + App.AirPCTheme.glassPadding * 2
                    color: App.AirPCTheme.glassBackground
                    radius: App.AirPCTheme.glassRadius
                    border.color: App.AirPCTheme.glassBorder
                    border.width: App.AirPCTheme.glassBorderWidth

                    ColumnLayout {
                        id: claimCardContent
                        anchors.fill: parent
                        anchors.margins: root.isMobile ? 20 : App.AirPCTheme.glassPadding
                        spacing: 16

                        Text {
                            text: qsTr("Claim Voucher")
                            font.pixelSize: App.AirPCTheme.cardTitleSize
                            font.weight: Font.DemiBold
                            font.family: App.AirPCTheme.fontFamily
                            color: App.AirPCTheme.textPrimary
                        }

                        Text {
                            Layout.fillWidth: true
                            text: qsTr("Enter your Shopee order ID to redeem voucher entitlement.")
                            font.pixelSize: 14
                            font.family: App.AirPCTheme.fontFamily
                            color: App.AirPCTheme.textMuted
                            wrapMode: Text.WordWrap
                            lineHeight: 1.5
                        }

                        TextField {
                            id: orderInput
                            Layout.fillWidth: true
                            Layout.preferredHeight: App.AirPCTheme.inputHeight
                            placeholderText: qsTr("Order ID (e.g. 241230TESTORD123)")
                            enabled: !root.isClaiming
                            font.pixelSize: 15
                            font.family: App.AirPCTheme.fontFamily
                            color: App.AirPCTheme.textPrimary
                            placeholderTextColor: App.AirPCTheme.textSecondary

                            background: Rectangle {
                                radius: App.AirPCTheme.inputRadius
                                color: orderInput.activeFocus ? App.AirPCTheme.inputBackgroundFocus : App.AirPCTheme.inputBackground
                                border.color: orderInput.activeFocus ? App.AirPCTheme.inputBorderFocus : App.AirPCTheme.inputBorder
                                border.width: 1.5

                                Behavior on color { ColorAnimation { duration: App.AirPCTheme.transitionDuration } }
                                Behavior on border.color { ColorAnimation { duration: App.AirPCTheme.transitionDuration } }
                            }

                            Keys.onReturnPressed: claimButton.clicked()
                            Keys.onEnterPressed: claimButton.clicked()
                        }

                        Text {
                            visible: root.claimError.length > 0
                            Layout.fillWidth: true
                            text: root.claimError
                            font.pixelSize: 13
                            font.family: App.AirPCTheme.fontFamily
                            color: App.AirPCTheme.danger
                            wrapMode: Text.WordWrap
                        }

                        App.PrimaryButton {
                            id: claimButton
                            Layout.fillWidth: true
                            text: root.isClaiming ? qsTr("Processing...") : qsTr("Redeem Order")
                            enabled: orderInput.text.trim().length > 0 && !root.isClaiming
                            loading: root.isClaiming

                            onClicked: {
                                root.isClaiming = true
                                root.claimError = ""
                                root.apiClient.claimOrder(orderInput.text.trim())
                            }
                        }
                    }
                }

                // History card (full width)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.columnSpan: root.width >= 768 ? 2 : 1
                    Layout.preferredHeight: historyCardContent.implicitHeight + App.AirPCTheme.glassPadding * 2
                    color: App.AirPCTheme.glassBackground
                    radius: App.AirPCTheme.glassRadius
                    border.color: App.AirPCTheme.glassBorder
                    border.width: App.AirPCTheme.glassBorderWidth

                    ColumnLayout {
                        id: historyCardContent
                        anchors.fill: parent
                        anchors.margins: root.isMobile ? 20 : App.AirPCTheme.glassPadding
                        spacing: 12

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Text {
                                text: qsTr("History")
                                font.pixelSize: App.AirPCTheme.cardTitleSize
                                font.weight: Font.DemiBold
                                font.family: App.AirPCTheme.fontFamily
                                color: App.AirPCTheme.textPrimary
                                Layout.fillWidth: true
                            }

                            Rectangle {
                                radius: 999
                                color: Qt.rgba(1, 1, 1, 0.25)
                                border.color: Qt.rgba(1, 1, 1, 0.15)
                                border.width: 1
                                implicitHeight: 38
                                implicitWidth: tabButtons.implicitWidth + 8

                                Row {
                                    id: tabButtons
                                    anchors.centerIn: parent
                                    spacing: 4

                                    Button {
                                        id: claimsTabButton
                                        checkable: true
                                        checked: root.activeTab === "claims"
                                        text: qsTr("Redemptions")
                                        onClicked: root.activeTab = "claims"

                                        contentItem: Text {
                                            text: claimsTabButton.text
                                            font.pixelSize: 13
                                            font.weight: Font.DemiBold
                                            font.family: App.AirPCTheme.fontFamily
                                            color: claimsTabButton.checked ? "#FFFFFF" : Qt.rgba(69/255, 69/255, 69/255, 0.72)
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }

                                        background: Rectangle {
                                            radius: 999
                                            color: claimsTabButton.checked ? App.AirPCTheme.primary : "transparent"
                                        }
                                    }

                                    Button {
                                        id: purchasesTabButton
                                        checkable: true
                                        checked: root.activeTab === "purchases"
                                        text: qsTr("Purchases")
                                        onClicked: root.activeTab = "purchases"

                                        contentItem: Text {
                                            text: purchasesTabButton.text
                                            font.pixelSize: 13
                                            font.weight: Font.DemiBold
                                            font.family: App.AirPCTheme.fontFamily
                                            color: purchasesTabButton.checked ? "#FFFFFF" : Qt.rgba(69/255, 69/255, 69/255, 0.72)
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }

                                        background: Rectangle {
                                            radius: 999
                                            color: purchasesTabButton.checked ? App.AirPCTheme.primary : "transparent"
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            visible: root.activeTab === "purchases" && root.purchases.length > 0
                            text: qsTr("Showing ") + root.purchases.length + qsTr(" of ") + root.purchaseCount + qsTr(" purchase(s)")
                            font.pixelSize: 13
                            font.family: App.AirPCTheme.fontFamily
                            color: App.AirPCTheme.textMuted
                        }

                        // Claims view
                        Item {
                            Layout.fillWidth: true
                            visible: root.activeTab === "claims"
                            implicitHeight: claimsColumn.implicitHeight

                            Text {
                                anchors.fill: parent
                                visible: root.claimHistory.length === 0
                                text: qsTr("No orders claimed yet.")
                                font.pixelSize: 14
                                font.family: App.AirPCTheme.fontFamily
                                color: App.AirPCTheme.textSecondary
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            ColumnLayout {
                                id: claimsColumn
                                visible: root.claimHistory.length > 0
                                anchors.left: parent.left
                                anchors.right: parent.right
                                spacing: 12

                                Repeater {
                                    model: root.claimHistory

                                    Rectangle {
                                        id: claimRow
                                        required property var modelData
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: root.isMobile ? 88 : 72
                                        color: Qt.rgba(1, 1, 1, 0.25)
                                        radius: 12
                                        border.color: Qt.rgba(1, 1, 1, 0.1)
                                        border.width: 1

                                        Item {
                                            id: claimRowContent
                                            anchors.fill: parent
                                            anchors.leftMargin: 14
                                            anchors.rightMargin: 14
                                            anchors.topMargin: 12
                                            anchors.bottomMargin: 12

                                            Rectangle {
                                                id: claimIconWrap
                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                implicitWidth: 36
                                                implicitHeight: 36
                                                radius: 10
                                                color: Qt.rgba(138/255, 28/255, 92/255, 0.10)

                                                Image {
                                                    anchors.centerIn: parent
                                                    source: "qrc:/res/baseline-check_circle_outline-24px.svg"
                                                    width: 20
                                                    height: 20
                                                    opacity: 0.85
                                                }
                                            }

                                            Text {
                                                id: claimGrantedText
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 96
                                                text: "+" + root.formatPlaytime(claimRow.modelData.playtime_granted || claimRow.modelData.playtimeGranted || 0)
                                                font.pixelSize: 16
                                                font.weight: Font.Bold
                                                font.family: App.AirPCTheme.fontFamily
                                                color: App.AirPCTheme.primary
                                                horizontalAlignment: Text.AlignRight
                                            }

                                            Column {
                                                anchors.left: claimIconWrap.right
                                                anchors.leftMargin: 12
                                                anchors.right: claimGrantedText.left
                                                anchors.rightMargin: 12
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 2

                                                Text {
                                                    text: claimRow.modelData.order_sn || claimRow.modelData.orderSn || ""
                                                    width: parent.width
                                                    font.pixelSize: 14
                                                    font.weight: Font.DemiBold
                                                    font.family: App.AirPCTheme.fontFamily
                                                    color: App.AirPCTheme.textPrimary
                                                    elide: Text.ElideRight
                                                }

                                                Text {
                                                    text: root.formatDate(claimRow.modelData.claimed_at || claimRow.modelData.claimedAt || "")
                                                    width: parent.width
                                                    font.pixelSize: 12
                                                    font.family: App.AirPCTheme.fontFamily
                                                    color: App.AirPCTheme.textSecondary
                                                    elide: Text.ElideRight
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Purchases view
                        Item {
                            Layout.fillWidth: true
                            visible: root.activeTab === "purchases"
                            implicitHeight: purchasesColumn.implicitHeight

                            ColumnLayout {
                                id: purchasesColumn
                                anchors.left: parent.left
                                anchors.right: parent.right
                                spacing: 12

                                Text {
                                    visible: root.purchaseError.length > 0
                                    Layout.fillWidth: true
                                    text: root.purchaseError
                                    font.pixelSize: 13
                                    font.family: App.AirPCTheme.fontFamily
                                    color: App.AirPCTheme.danger
                                    wrapMode: Text.WordWrap
                                }

                                Text {
                                    visible: !root.isLoadingPurchases && root.purchases.length === 0 && root.purchaseError.length === 0
                                    Layout.fillWidth: true
                                    text: qsTr("No purchases yet.")
                                    font.pixelSize: 14
                                    font.family: App.AirPCTheme.fontFamily
                                    color: App.AirPCTheme.textSecondary
                                    horizontalAlignment: Text.AlignHCenter
                                }

                                Repeater {
                                    model: root.purchases

                                    Rectangle {
                                        id: purchaseRow
                                        required property var modelData
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: root.isMobile ? 132 : 96
                                        color: Qt.rgba(1, 1, 1, 0.25)
                                        radius: 12
                                        border.color: Qt.rgba(1, 1, 1, 0.1)
                                        border.width: 1

                                        Item {
                                            id: purchaseRowContent
                                            anchors.fill: parent
                                            anchors.leftMargin: 14
                                            anchors.rightMargin: 14
                                            anchors.topMargin: 12
                                            anchors.bottomMargin: 12

                                            Rectangle {
                                                id: purchaseIconWrap
                                                anchors.left: parent.left
                                                anchors.top: parent.top
                                                implicitWidth: 36
                                                implicitHeight: 36
                                                radius: 10
                                                color: Qt.rgba(138/255, 28/255, 92/255, 0.10)

                                                Image {
                                                    anchors.centerIn: parent
                                                    source: "qrc:/res/ic_add_to_queue_white_48px.svg"
                                                    width: 20
                                                    height: 20
                                                    opacity: 0.85
                                                }
                                            }

                                            Item {
                                                id: purchaseMetaColumn
                                                anchors.top: parent.top
                                                anchors.left: purchaseIconWrap.right
                                                anchors.leftMargin: 12
                                                anchors.right: purchaseSummaryColumn.left
                                                anchors.rightMargin: 12
                                                anchors.bottom: parent.bottom

                                                Column {
                                                    width: parent.width
                                                    spacing: 2

                                                    Text {
                                                        text: root.getPurchaseTitle(purchaseRow.modelData)
                                                        font.pixelSize: 14
                                                        font.weight: Font.DemiBold
                                                        font.family: App.AirPCTheme.fontFamily
                                                        color: App.AirPCTheme.textPrimary
                                                        elide: Text.ElideRight
                                                        width: parent.width
                                                    }

                                                    Text {
                                                        text: (purchaseRow.modelData.order_number || "") + " - " + root.formatDate(purchaseRow.modelData.created_at || "")
                                                        font.pixelSize: 12
                                                        font.family: App.AirPCTheme.fontFamily
                                                        color: App.AirPCTheme.textSecondary
                                                        elide: Text.ElideRight
                                                        width: parent.width
                                                    }

                                                    Text {
                                                        visible: purchaseRow.modelData.fulfillment_type && purchaseRow.modelData.fulfillment_type !== "none"
                                                        text: qsTr("Fulfillment: ") + purchaseRow.modelData.fulfillment_type
                                                        font.pixelSize: 12
                                                        font.family: App.AirPCTheme.fontFamily
                                                        color: App.AirPCTheme.textSecondary
                                                        elide: Text.ElideRight
                                                        width: parent.width
                                                    }

                                                    Text {
                                                        property string periodLabel: root.getPurchasePeriodLabel(purchaseRow.modelData)
                                                        visible: periodLabel.length > 0
                                                        text: periodLabel
                                                        font.pixelSize: 12
                                                        font.family: App.AirPCTheme.fontFamily
                                                        color: App.AirPCTheme.textSecondary
                                                        elide: Text.ElideRight
                                                        width: parent.width
                                                    }
                                                }
                                            }

                                            Item {
                                                id: purchaseSummaryColumn
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 168
                                                height: summaryContent.implicitHeight

                                                Column {
                                                    id: summaryContent
                                                    anchors.right: parent.right
                                                    spacing: 6

                                                    Text {
                                                        text: root.formatMoney(purchaseRow.modelData.amount ? purchaseRow.modelData.amount.currency : "MYR",
                                                                               purchaseRow.modelData.amount ? purchaseRow.modelData.amount.value : 0)
                                                        font.pixelSize: 16
                                                        font.weight: Font.Bold
                                                        font.family: App.AirPCTheme.fontFamily
                                                        color: "#174871"
                                                        horizontalAlignment: Text.AlignRight
                                                        width: parent.width
                                                    }

                                                    Rectangle {
                                                        anchors.right: parent.right
                                                        radius: 999
                                                        color: root.getStatusBg(purchaseRow.modelData.status)
                                                        implicitHeight: 24
                                                        implicitWidth: statusText.implicitWidth + 18

                                                        Text {
                                                            id: statusText
                                                            anchors.centerIn: parent
                                                            text: root.getStatusLabel(purchaseRow.modelData.status)
                                                            font.pixelSize: 12
                                                            font.weight: Font.Bold
                                                            font.family: App.AirPCTheme.fontFamily
                                                            color: root.getStatusColor(purchaseRow.modelData.status)
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                Button {
                                    id: loadMoreButton
                                    visible: root.hasMorePurchases
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 44
                                    enabled: !root.isLoadingPurchases
                                    text: root.isLoadingPurchases ? qsTr("Loading...") : qsTr("Load More")

                                    onClicked: {
                                        root.purchaseAppendMode = true
                                        root.isLoadingPurchases = true
                                        root.apiClient.fetchBillingPurchases(root.purchasePage + 1, 10)
                                    }

                                    background: Rectangle {
                                        radius: 22
                                        color: Qt.rgba(1, 1, 1, 0.25)
                                        border.color: Qt.rgba(69/255, 69/255, 69/255, 0.2)
                                        border.width: 1
                                    }

                                    contentItem: Text {
                                        text: loadMoreButton.text
                                        font.pixelSize: 14
                                        font.weight: Font.DemiBold
                                        font.family: App.AirPCTheme.fontFamily
                                        color: App.AirPCTheme.textPrimary
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Item { Layout.preferredHeight: 80 }
        }
    }
}
