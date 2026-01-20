import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import AirPCApiClient 1.0
import "." as App

/**
 * ProfileView - User profile page matching web client design.
 *
 * Features:
 *   - AirPC gradient background
 *   - Glassmorphism cards (4-card grid layout)
 *   - Profile info with avatar
 *   - Playtime balance display
 *   - Order claim form
 *   - Redemption history list
 *
 * Web Reference: ProfilePage.tsx + ProfilePage.module.css
 */
FocusScope {
    id: root
    objectName: qsTr("Profile")

    // Profile properties
    property string username: ""
    property string email: ""
    property int accountId: 0
    property int playtimeSeconds: 0
    property int claimCount: 0
    property var claimHistory: []
    property bool isLoading: true
    property bool isClaiming: false
    property string claimError: ""

    // Format helpers
    function formatPlaytime(seconds) {
        if (seconds <= 0) return "0m"
        var hours = Math.floor(seconds / 3600)
        var minutes = Math.floor((seconds % 3600) / 60)
        if (hours > 0 && minutes > 0) return hours + "h " + minutes + "m"
        if (hours > 0) return hours + "h"
        return minutes + "m"
    }

    function formatDate(dateStr) {
        var d = new Date(dateStr)
        var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        return months[d.getMonth()] + " " + d.getDate() + ", " + d.getFullYear()
    }

    // Load profile data
    Component.onCompleted: {
        AirPCApiClient.fetchProfile()
        AirPCApiClient.fetchClaimHistory()
    }

    // API connections
    Connections {
        target: AirPCApiClient

        function onProfileLoaded(playtimeSec, claimCnt, uname, mail) {
            root.username = uname || ""
            root.email = mail || ""
            root.playtimeSeconds = playtimeSec || 0
            root.claimCount = claimCnt || 0
            root.isLoading = false
        }

        function onClaimHistoryReceived(claims) {
            root.claimHistory = claims || []
        }

        function onClaimSucceeded(granted, total) {
            root.isClaiming = false
            root.playtimeSeconds = total
            root.claimError = ""
            orderInput.text = ""
            AirPCApiClient.fetchClaimHistory()
            AirPCApiClient.fetchProfile()
        }

        function onClaimFailed(error) {
            root.isClaiming = false
            root.claimError = error
        }
    }

    // AirPC Gradient Background
    Rectangle {
        id: background
        anchors.fill: parent

        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: App.AirPCTheme.gradientStop1 }
            GradientStop { position: 0.33; color: App.AirPCTheme.gradientStop2 }
            GradientStop { position: 0.66; color: App.AirPCTheme.gradientStop3 }
            GradientStop { position: 1.0; color: App.AirPCTheme.gradientStop4 }
        }

        // Diagonal overlay
        Rectangle {
            anchors.fill: parent
            rotation: -45
            scale: 1.5
            transformOrigin: Item.Center

            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(222/255, 209/255, 198/255, 0.3) }
                GradientStop { position: 0.5; color: "transparent" }
                GradientStop { position: 1.0; color: Qt.rgba(15/255, 45/255, 77/255, 0.3) }
            }
        }
    }

    // Loading state
    Item {
        anchors.fill: parent
        visible: root.isLoading

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 16

            BusyIndicator {
                Layout.alignment: Qt.AlignHCenter
                running: root.isLoading
                palette.dark: App.AirPCTheme.textOnGradient
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

    // Main Content
    ScrollView {
        anchors.fill: parent
        visible: !root.isLoading
        contentWidth: availableWidth
        clip: true

        ScrollBar.vertical.policy: ScrollBar.AsNeeded
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        ColumnLayout {
            width: Math.min(parent.width, 900)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 24

            // Top padding
            Item { Layout.preferredHeight: App.AirPCTheme.contentPaddingV }

            // Page Header
            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: App.AirPCTheme.contentPaddingH
                Layout.rightMargin: App.AirPCTheme.contentPaddingH
                spacing: 8

                Text {
                    text: qsTr("User Profile")
                    font.pixelSize: App.AirPCTheme.pageTitleSize
                    font.weight: Font.Bold
                    font.family: App.AirPCTheme.fontFamily
                    color: App.AirPCTheme.textOnGradient
                }

                Text {
                    text: qsTr("Manage your account and claim playtime")
                    font.pixelSize: App.AirPCTheme.pageSubtitleSize
                    font.family: App.AirPCTheme.fontFamily
                    color: App.AirPCTheme.textOnGradientMuted
                }
            }

            // Spacer
            Item { Layout.preferredHeight: 8 }

            // Main Grid (2 columns on wide screens)
            GridLayout {
                Layout.fillWidth: true
                Layout.leftMargin: App.AirPCTheme.contentPaddingH
                Layout.rightMargin: App.AirPCTheme.contentPaddingH
                columns: root.width > 768 ? 2 : 1
                rowSpacing: 24
                columnSpacing: 24

                // ==========================================
                // Card 1: Profile Info
                // ==========================================
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
                        anchors.margins: App.AirPCTheme.glassPadding
                        spacing: 24

                        // Header with avatar
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 20

                            // Avatar
                            Rectangle {
                                width: App.AirPCTheme.avatarSize
                                height: App.AirPCTheme.avatarSize
                                radius: width / 2
                                color: App.AirPCTheme.primary

                                // Avatar shadow
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
                                    font.pixelSize: App.AirPCTheme.avatarFontSize
                                    font.weight: Font.Bold
                                    font.family: App.AirPCTheme.fontFamily
                                    color: App.AirPCTheme.textOnPrimary
                                }
                            }

                            // User meta
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                Text {
                                    text: root.username || qsTr("User")
                                    font.pixelSize: 22
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

                        // Stats row
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 16

                            // Account ID stat
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
                                        text: qsTr("ACCOUNT ID")
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

                            // Total claims stat
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
                                        text: qsTr("TOTAL CLAIMS")
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

                // ==========================================
                // Card 2: Playtime Balance
                // ==========================================
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: playtimeCardContent.implicitHeight + App.AirPCTheme.glassPadding * 2

                    // Subtle gradient tint for playtime card
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(233/255, 69/255, 96/255, 0.1) }
                        GradientStop { position: 1.0; color: App.AirPCTheme.glassBackground }
                    }

                    radius: App.AirPCTheme.glassRadius
                    border.color: App.AirPCTheme.glassBorder
                    border.width: App.AirPCTheme.glassBorderWidth

                    ColumnLayout {
                        id: playtimeCardContent
                        anchors.fill: parent
                        anchors.margins: App.AirPCTheme.glassPadding
                        spacing: 16

                        Text {
                            text: qsTr("Playtime Balance")
                            font.pixelSize: App.AirPCTheme.cardTitleSize
                            font.weight: Font.DemiBold
                            font.family: App.AirPCTheme.fontFamily
                            color: App.AirPCTheme.textPrimary
                        }

                        // Centered playtime display
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                            spacing: 8

                            Item { Layout.fillHeight: true }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: formatPlaytime(root.playtimeSeconds)
                                font.pixelSize: App.AirPCTheme.playtimeValueSize
                                font.weight: Font.ExtraBold
                                font.family: App.AirPCTheme.fontFamily
                                color: App.AirPCTheme.primary
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: qsTr("Available")
                                font.pixelSize: 14
                                font.family: App.AirPCTheme.fontFamily
                                color: App.AirPCTheme.textSecondary
                            }

                            Item { Layout.fillHeight: true }
                        }
                    }
                }

                // ==========================================
                // Card 3: Claim Playtime
                // ==========================================
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
                        anchors.margins: App.AirPCTheme.glassPadding
                        spacing: 16

                        Text {
                            text: qsTr("Claim Playtime")
                            font.pixelSize: App.AirPCTheme.cardTitleSize
                            font.weight: Font.DemiBold
                            font.family: App.AirPCTheme.fontFamily
                            color: App.AirPCTheme.textPrimary
                        }

                        Text {
                            Layout.fillWidth: true
                            text: qsTr("Enter your Shopee order ID to redeem 2 hours of playtime.")
                            font.pixelSize: 14
                            font.family: App.AirPCTheme.fontFamily
                            color: App.AirPCTheme.textMuted
                            wrapMode: Text.WordWrap
                            lineHeight: 1.5
                        }

                        // Order input
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
                                color: orderInput.activeFocus ?
                                    App.AirPCTheme.inputBackgroundFocus : App.AirPCTheme.inputBackground
                                border.color: orderInput.activeFocus ?
                                    App.AirPCTheme.inputBorderFocus : App.AirPCTheme.inputBorder
                                border.width: 1.5

                                Behavior on color {
                                    ColorAnimation { duration: App.AirPCTheme.transitionDuration }
                                }

                                Behavior on border.color {
                                    ColorAnimation { duration: App.AirPCTheme.transitionDuration }
                                }
                            }

                            Keys.onReturnPressed: claimButton.clicked()
                            Keys.onEnterPressed: claimButton.clicked()
                        }

                        // Error message
                        Text {
                            visible: root.claimError.length > 0
                            Layout.fillWidth: true
                            text: root.claimError
                            font.pixelSize: 13
                            font.family: App.AirPCTheme.fontFamily
                            color: App.AirPCTheme.danger
                            wrapMode: Text.WordWrap
                        }

                        // Claim button
                        App.PrimaryButton {
                            id: claimButton
                            Layout.fillWidth: true
                            text: root.isClaiming ? qsTr("Processing...") : qsTr("Redeem Order")
                            enabled: orderInput.text.trim().length > 0 && !root.isClaiming
                            loading: root.isClaiming

                            onClicked: {
                                root.isClaiming = true
                                root.claimError = ""
                                AirPCApiClient.claimOrder(orderInput.text.trim())
                            }
                        }
                    }
                }

                // ==========================================
                // Card 4: Redemption History (full width)
                // ==========================================
                Rectangle {
                    Layout.fillWidth: true
                    Layout.columnSpan: root.width > 768 ? 2 : 1
                    Layout.preferredHeight: historyCardContent.implicitHeight + App.AirPCTheme.glassPadding * 2
                    color: App.AirPCTheme.glassBackground
                    radius: App.AirPCTheme.glassRadius
                    border.color: App.AirPCTheme.glassBorder
                    border.width: App.AirPCTheme.glassBorderWidth

                    ColumnLayout {
                        id: historyCardContent
                        anchors.fill: parent
                        anchors.margins: App.AirPCTheme.glassPadding
                        spacing: 16

                        Text {
                            text: qsTr("Redemption History")
                            font.pixelSize: App.AirPCTheme.cardTitleSize
                            font.weight: Font.DemiBold
                            font.family: App.AirPCTheme.fontFamily
                            color: App.AirPCTheme.textPrimary
                        }

                        // Empty state
                        Text {
                            visible: root.claimHistory.length === 0
                            Layout.fillWidth: true
                            Layout.preferredHeight: 60
                            text: qsTr("No orders claimed yet.")
                            font.pixelSize: 14
                            font.family: App.AirPCTheme.fontFamily
                            color: App.AirPCTheme.textSecondary
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        // History list
                        ColumnLayout {
                            visible: root.claimHistory.length > 0
                            Layout.fillWidth: true
                            spacing: 12

                            Repeater {
                                model: root.claimHistory

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 62
                                    color: App.AirPCTheme.glassInner
                                    radius: App.AirPCTheme.glassInnerRadius
                                    border.color: Qt.rgba(255, 255, 255, 0.1)
                                    border.width: 1

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 16
                                        anchors.rightMargin: 16
                                        spacing: 12

                                        // Icon
                                        Rectangle {
                                            width: 36
                                            height: 36
                                            radius: 10
                                            color: App.AirPCTheme.primaryHover

                                            Text {
                                                anchors.centerIn: parent
                                                text: "\u23F0"  // Clock emoji
                                                font.pixelSize: 16
                                            }
                                        }

                                        // Order info
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2

                                            Text {
                                                text: modelData.order_sn || modelData.orderSn || ""
                                                font.pixelSize: 14
                                                font.weight: Font.DemiBold
                                                font.family: App.AirPCTheme.fontFamily
                                                color: App.AirPCTheme.textPrimary
                                            }

                                            Text {
                                                text: formatDate(modelData.claimed_at || modelData.claimedAt || "")
                                                font.pixelSize: 12
                                                font.family: App.AirPCTheme.fontFamily
                                                color: App.AirPCTheme.textSecondary
                                            }
                                        }

                                        // Granted amount
                                        Text {
                                            text: "+" + formatPlaytime(modelData.playtime_granted || modelData.playtimeGranted || 0)
                                            font.pixelSize: 16
                                            font.weight: Font.Bold
                                            font.family: App.AirPCTheme.fontFamily
                                            color: App.AirPCTheme.primary
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Bottom padding
            Item { Layout.preferredHeight: 80 }
        }
    }
}
