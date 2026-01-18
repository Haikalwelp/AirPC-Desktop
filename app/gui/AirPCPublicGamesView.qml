import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

import AirPCGameModel 1.0
import AirPCApiClient 1.0
import Session 1.0
import PlaytimeManager 1.0

Item {
    id: root
    objectName: "Game Library"

    // ============================================================================
    // Design System (mirrors web GameLibraryPage + GameCard)
    // ============================================================================

    readonly property color primary: "#8A1C5C"
    readonly property color textOnDark: "#FFFFFF"
    readonly property color textMutedOnDark: Qt.rgba(1, 1, 1, 0.7)

    readonly property color textPrimary: "#454545"
    readonly property color textMuted: Qt.rgba(69/255, 69/255, 69/255, 0.6)

    readonly property color glass: Qt.rgba(1, 1, 1, 0.25)
    readonly property color glassLight: Qt.rgba(1, 1, 1, 0.15)
    readonly property color glassBorder: Qt.rgba(1, 1, 1, 0.18)

    readonly property color danger: "#F94141"
    readonly property color dangerBg: Qt.rgba(249/255, 65/255, 65/255, 0.15)
    readonly property color dangerBorder: Qt.rgba(249/255, 65/255, 65/255, 0.3)

    readonly property int pagePadding: 24
    readonly property int maxContentWidth: 1400

    readonly property bool isNarrow: width < 768

    // Responsive sizing (mirrors web CSS breakpoints)
    readonly property int gridGap: width < 640 ? 20 : (width < 1024 ? 24 : 28)
    readonly property int cardWidth: width < 640 ? 160 : (width < 1024 ? 180 : 200)
    readonly property int cardHeight: Math.round(cardWidth * 1.50)

    // State
    property string searchQuery: ""
    property string selectedFilter: "All" // purely UI for now

    // Signals
    signal streamLaunched(string sessionId, string streamHost, int streamPort, int httpsPort)
    signal logoutRequested()

    // ============================================================================
    // Inline Components
    // ============================================================================

    component GlassIconButton: ToolButton {
        id: btn

        property string tooltip: ""

        implicitWidth: 44
        implicitHeight: 44

        background: Rectangle {
            radius: 12
            color: btn.down ? Qt.rgba(1, 1, 1, 0.22) : (btn.hovered ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.12))
            border.color: Qt.rgba(1, 1, 1, 0.18)
            border.width: 1

            Behavior on color { ColorAnimation { duration: 120 } }
        }

        ToolTip.visible: tooltip.length > 0 && hovered
        ToolTip.text: tooltip
    }

    component FilterPill: Rectangle {
        id: pill

        property string text: ""
        property bool isSelected: false
        signal clicked()

        height: 36
        radius: 22
        width: label.implicitWidth + 32

        color: isSelected ? root.primary : Qt.rgba(1, 1, 1, 0.10)
        border.color: isSelected ? root.primary : Qt.rgba(69/255, 69/255, 69/255, 0.20)
        border.width: 1.5

        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }

        Text {
            id: label
            anchors.centerIn: parent
            text: pill.text
            font.pixelSize: 14
            font.weight: Font.Medium
            font.family: "Montserrat"
            color: isSelected ? root.textOnDark : root.textPrimary
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.clicked()
        }
    }

    component GameCard: Item {
        id: card

        property string title: ""
        property string imageUrl: ""
        signal clicked()

        // Interaction
        property bool hovered: mouseArea.containsMouse
        property bool pressed: mouseArea.pressed

        opacity: 0
        scale: pressed ? 0.985 : (hovered ? 1.02 : 1.0)
        y: hovered ? -6 : 0

        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        Component.onCompleted: appearAnim.start()

        NumberAnimation {
            id: appearAnim
            target: card
            property: "opacity"
            to: 1
            duration: 220
            easing.type: Easing.OutCubic
        }

        Rectangle {
            id: frame
            anchors.fill: parent
            radius: 16
            clip: true

            color: root.glassLight
            border.color: card.hovered ? Qt.rgba(138/255, 28/255, 92/255, 0.40) : Qt.rgba(1, 1, 1, 0.20)
            border.width: 1.5

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.rgba(0, 0, 0, 0.12)
                shadowVerticalOffset: card.hovered ? 18 : 10
                shadowHorizontalOffset: 0
                shadowBlur: card.hovered ? 0.7 : 0.55
            }

            // Cover
            Rectangle {
                id: coverContainer
                anchors.fill: parent
                color: "transparent"

                // Gradient base (like web placeholder background)
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(138/255, 28/255, 92/255, 0.18) }
                        GradientStop { position: 1.0; color: Qt.rgba(23/255, 72/255, 113/255, 0.28) }
                    }
                }

                Image {
                    id: coverImage
                    anchors.fill: parent
                    source: card.imageUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true

                    // Hover treatment
                    scale: card.hovered ? 1.05 : 1.0
                    opacity: (status === Image.Ready) ? 1 : 0

                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                }

                // Loading placeholder
                Item {
                    anchors.fill: parent
                    visible: coverImage.status !== Image.Ready

                    BusyIndicator {
                        anchors.centerIn: parent
                        running: coverImage.status === Image.Loading
                        visible: coverImage.status === Image.Loading
                        width: 28
                        height: 28
                    }

                    Image {
                        id: placeholderIcon
                        anchors.centerIn: parent
                        source: "qrc:/res/ic_videogame_asset_white_48px.svg"
                        width: 42
                        height: 42
                        visible: coverImage.status !== Image.Loading
                        opacity: 0.35
                    }
                }

                // Title overlay gradient
                Rectangle {
                    id: titleOverlay
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 74

                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.0) }
                        GradientStop { position: 0.4; color: Qt.rgba(0, 0, 0, 0.55) }
                        GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.90) }
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        anchors.bottomMargin: 12

                        text: card.title
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        font.family: "Montserrat"
                        color: root.textOnDark
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        wrapMode: Text.Wrap
                    }
                }

                // Play overlay (web-style)
                Rectangle {
                    id: playOverlay
                    width: 56
                    height: 56
                    radius: 28
                    anchors.centerIn: parent

                    color: root.primary
                    opacity: card.hovered ? 1 : 0
                    scale: card.hovered ? 1.0 : 0.8

                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.05 } }

                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: Qt.rgba(138/255, 28/255, 92/255, 0.40)
                        shadowVerticalOffset: 10
                        shadowBlur: 0.7
                    }

                    Image {
                        anchors.centerIn: parent
                        source: "qrc:/res/play_arrow_FILL1_wght700_GRAD200_opsz48.svg"
                        width: 30
                        height: 30
                        opacity: 0.95
                    }
                }

                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: card.clicked()
                }
            }
        }
    }

    component ActiveSessionCard: Rectangle {
        id: sessionCard

        property var session: null
        signal resumeClicked()
        signal endClicked()

        height: 84
        radius: 16
        color: root.glass
        border.color: Qt.rgba(138/255, 28/255, 92/255, 0.60)
        border.width: 1.5

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.12)
            shadowVerticalOffset: 14
            shadowBlur: 0.65
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 14

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: sessionCard.session ? (sessionCard.session.appName) : ""
                    font.pixelSize: 16
                    font.weight: Font.Bold
                    font.family: "Montserrat"
                    color: root.textOnDark
                    elide: Text.ElideRight
                }

                RowLayout {
                    spacing: 12

                    Text {
                        text: sessionCard.session ? ("On " + sessionCard.session.computerName) : ""
                        font.pixelSize: 12
                        font.family: "Montserrat"
                        color: root.textMutedOnDark
                        elide: Text.ElideRight
                    }

                    // Session remaining time
                    Text {
                        visible: PlaytimeManager.isSessionActive
                        text: "Time: " + PlaytimeManager.formattedRemaining
                        color: PlaytimeManager.remainingSeconds < 300 ? "#ef4444" : "#22c55e"
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        font.family: "Montserrat"
                    }
                }
            }

            Button {
                text: "Resume"

                contentItem: Text {
                    text: parent.text
                    color: root.textOnDark
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    font.family: "Montserrat"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                background: Rectangle {
                    color: root.primary
                    radius: 10
                    implicitWidth: 92
                    implicitHeight: 40
                }

                onClicked: sessionCard.resumeClicked()
            }

            Button {
                text: "End"

                contentItem: Text {
                    text: parent.text
                    color: root.textPrimary
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    font.family: "Montserrat"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                background: Rectangle {
                    color: Qt.rgba(1, 1, 1, 0.25)
                    radius: 10
                    implicitWidth: 70
                    implicitHeight: 40
                    border.color: Qt.rgba(1, 1, 1, 0.18)
                    border.width: 1
                }

                onClicked: sessionCard.endClicked()
            }
        }
    }

    // ============================================================================
    // Background
    // ============================================================================

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: "#DED1C6" }
            GradientStop { position: 0.33; color: "#A77693" }
            GradientStop { position: 0.66; color: "#174871" }
            GradientStop { position: 1.0; color: "#0F2D4D" }
        }
    }

    // ============================================================================
    // Page Content (centered max-width like web)
    // ============================================================================

    Item {
        id: page
        anchors.fill: parent
        anchors.margins: root.pagePadding

        ColumnLayout {
            id: content
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(parent.width, root.maxContentWidth)
            spacing: 16

            // Header (simple; web page has none but desktop benefits)
            RowLayout {
                Layout.fillWidth: true

                ColumnLayout {
                    spacing: 2

                    Text {
                        text: "Game Library"
                        font.pixelSize: 24
                        font.weight: Font.Bold
                        font.family: "Montserrat"
                        color: root.textOnDark
                    }

                    Text {
                        visible: gameModelInstance.loading
                        text: "Loading games..."
                        font.pixelSize: 12
                        font.family: "Montserrat"
                        color: root.textMutedOnDark
                    }
                }

                Item { Layout.fillWidth: true }

                GlassIconButton {
                    id: userMenuBtn
                    tooltip: "Settings"
                    icon.source: "qrc:/res/settings.svg"
                    icon.width: 22
                    icon.height: 22
                    onClicked: userMenu.open()

                    Menu {
                        id: userMenu
                        y: userMenuBtn.height

                        MenuItem {
                            text: "Settings"
                            onTriggered: StackView.view.push("qrc:/gui/SettingsView.qml")
                        }
                        MenuItem {
                            text: "Logout"
                            onTriggered: {
                                AirPCApiClient.logout()
                                root.logoutRequested()
                            }
                        }
                    }
                }
            }

            // Controls Bar (web-style glass)
            Rectangle {
                id: controlsBar
                Layout.fillWidth: true
                radius: 16
                color: root.glass
                border.color: root.glassBorder
                border.width: 1.5

                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Qt.rgba(0, 0, 0, 0.10)
                    shadowVerticalOffset: 16
                    shadowBlur: 0.65
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    // Wide layout: search + filters + refresh in one row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        visible: !root.isNarrow

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 48

                            TextField {
                                id: searchFieldWide
                                anchors.fill: parent
                                placeholderText: "Search games..."
                                font.pixelSize: 14
                                font.family: "Montserrat"
                                leftPadding: 44
                                rightPadding: 16

                                background: Rectangle {
                                    color: Qt.rgba(1, 1, 1, 0.15)
                                    border.color: searchFieldWide.activeFocus ? root.primary : Qt.rgba(69/255, 69/255, 69/255, 0.20)
                                    border.width: 1
                                    radius: 12

                                    Behavior on border.color { ColorAnimation { duration: 150 } }
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }

                                onTextChanged: root.searchQuery = text
                            }

                            Image {
                                anchors.left: parent.left
                                anchors.leftMargin: 14
                                anchors.verticalCenter: parent.verticalCenter
                                source: "qrc:/res/search.svg"
                                width: 20
                                height: 20
                                opacity: 0.55
                            }
                        }

                        Row {
                            spacing: 8

                            FilterPill {
                                text: "All Games"
                                isSelected: root.selectedFilter === "All"
                                onClicked: root.selectedFilter = "All"
                            }
                            FilterPill {
                                text: "Recent"
                                isSelected: root.selectedFilter === "Recent"
                                onClicked: root.selectedFilter = "Recent"
                            }
                        }

                        GlassIconButton {
                            tooltip: "Refresh Library"
                            icon.source: "qrc:/res/refresh.svg"
                            icon.width: 20
                            icon.height: 20
                            enabled: !gameModelInstance.loading
                            onClicked: gameModelInstance.refresh()
                        }
                    }

                    // Narrow layout: search then horizontal filters row
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        visible: root.isNarrow

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 48

                            TextField {
                                id: searchFieldNarrow
                                anchors.fill: parent
                                placeholderText: "Search games..."
                                font.pixelSize: 14
                                font.family: "Montserrat"
                                leftPadding: 44
                                rightPadding: 16

                                background: Rectangle {
                                    color: Qt.rgba(1, 1, 1, 0.15)
                                    border.color: searchFieldNarrow.activeFocus ? root.primary : Qt.rgba(69/255, 69/255, 69/255, 0.20)
                                    border.width: 1
                                    radius: 12

                                    Behavior on border.color { ColorAnimation { duration: 150 } }
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }

                                onTextChanged: root.searchQuery = text
                            }

                            Image {
                                anchors.left: parent.left
                                anchors.leftMargin: 14
                                anchors.verticalCenter: parent.verticalCenter
                                source: "qrc:/res/search.svg"
                                width: 20
                                height: 20
                                opacity: 0.55
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Flickable {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 36
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds
                                flickableDirection: Flickable.HorizontalFlick

                                contentWidth: filterRow.width

                                Row {
                                    id: filterRow
                                    spacing: 8

                                    FilterPill {
                                        text: "All Games"
                                        isSelected: root.selectedFilter === "All"
                                        onClicked: root.selectedFilter = "All"
                                    }
                                    FilterPill {
                                        text: "Recent"
                                        isSelected: root.selectedFilter === "Recent"
                                        onClicked: root.selectedFilter = "Recent"
                                    }
                                }

                                ScrollBar.horizontal: ScrollBar {
                                    policy: ScrollBar.AlwaysOff
                                }
                            }

                            GlassIconButton {
                                tooltip: "Refresh Library"
                                icon.source: "qrc:/res/refresh.svg"
                                icon.width: 20
                                icon.height: 20
                                enabled: !gameModelInstance.loading
                                onClicked: gameModelInstance.refresh()
                            }
                        }
                    }
                }
            }

            // Error banner intentionally hidden (user-facing UX)
            Rectangle {
                Layout.fillWidth: true
                visible: false
                radius: 12
                color: root.dangerBg
                border.color: root.dangerBorder
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    Text {
                        text: "Unable to load library"
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        font.family: "Montserrat"
                        color: root.danger
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: gameModelInstance.errorMessage
                        font.pixelSize: 12
                        font.family: "Montserrat"
                        color: Qt.rgba(1, 1, 1, 0.85)
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideRight
                        Layout.maximumWidth: Math.max(220, root.width * 0.45)
                    }
                }
            }

            // Active session card
            ActiveSessionCard {
                Layout.fillWidth: true
                visible: AirPCApiClient.hasActiveSession
                session: AirPCApiClient.activeSession
                onResumeClicked: AirPCApiClient.resumeSession()
                onEndClicked: AirPCApiClient.endSession()
            }

            // Content Area
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                // (Sizing is defined on `root` to avoid delegate scoping issues)

                // Loading state (only when empty)
                BusyIndicator {
                    anchors.centerIn: parent
                    running: gameModelInstance.loading
                    visible: gameModelInstance.loading && gameGrid.count === 0
                    width: 52
                    height: 52
                }

                // Empty state (includes fetch failures; no error details shown)
                ColumnLayout {
                    anchors.centerIn: parent
                    visible: !gameModelInstance.loading && gameGrid.count === 0
                    spacing: 10

                    Text {
                        text: "Apps not found"
                        font.pixelSize: 20
                        font.weight: Font.Bold
                        font.family: "Montserrat"
                        color: root.textOnDark
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: "No apps were returned from your allocations."
                        font.pixelSize: 14
                        font.family: "Montserrat"
                        color: root.textMutedOnDark
                        Layout.alignment: Qt.AlignHCenter
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        Layout.maximumWidth: 360
                    }

                    Button {
                        text: "Refresh"
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 14

                        contentItem: Text {
                            text: parent.text
                            color: root.textOnDark
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            font.family: "Montserrat"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        background: Rectangle {
                            color: root.primary
                            radius: 10
                            implicitWidth: 110
                            implicitHeight: 42
                        }

                        onClicked: gameModelInstance.refresh()
                    }
                }

                // Game grid (centered, responsive)
                CenteredGridView {
                    id: gameGrid
                    anchors.fill: parent
                    visible: gameGrid.count > 0
                    clip: true

                    cellWidth: root.cardWidth + root.gridGap
                    cellHeight: root.cardHeight + root.gridGap

                    model: AirPCGameSortFilterModel {
                        id: sortFilterModel
                        sourceModel: gameModelInstance
                        filterText: root.searchQuery
                    }

                    delegate: GameCard {
                        width: root.cardWidth
                        height: root.cardHeight

                        title: model.title
                        imageUrl: model.imageUrl

                        onClicked: {
                            console.log("Launching game:", model.title)
                            sortFilterModel.launchGame(index)
                        }
                    }

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                    }
                }
            }
        }
    }

    // Error Dialog (kept for launch/stream failures)
    Dialog {
        id: errorDialog
        title: "Connection Error"
        modal: true
        anchors.centerIn: parent
        standardButtons: Dialog.Ok

        property string errorMessage: ""

        Label {
            text: errorDialog.errorMessage
            wrapMode: Text.Wrap
            width: parent.width
        }
    }

    // Game Model Instance
    AirPCGameModel {
        id: gameModelInstance
    }

    // Handle stream launch events
    Connections {
        target: gameModelInstance

        function onGameLaunched(sessionId, streamHost, streamPort, httpsPort) {
            console.log("Stream launched:", sessionId, streamHost, streamPort)
            root.streamLaunched(sessionId, streamHost, streamPort, httpsPort)
        }

        function onLaunchFailed(error) {
            console.log("AirPCPublicGamesView: Launch failed -", error)
            errorDialog.errorMessage = error
            errorDialog.open()
        }

        function onStreamStarted() {
            console.log("AirPCPublicGamesView: Stream started")
        }

        function onStreamEnded(reason) {
            console.log("AirPCPublicGamesView: Stream ended -", reason)
        }

        function onStreamError(error) {
            console.log("AirPCPublicGamesView: Stream error -", error)
            errorDialog.errorMessage = error
            errorDialog.open()
        }

        function onSessionCreated(appName, session) {
            console.log("AirPCPublicGamesView: Session created for", appName)

            // Navigate to StreamSegue to begin the streaming session
            // Following the pattern from AppView.qml
            var component = Qt.createComponent("StreamSegue.qml")
            var segue = component.createObject(stackView, {
                "appName": appName,
                "session": session,
                "isResume": false
            })
            stackView.push(segue)
        }
    }

    // Auto-refresh on component load
    Component.onCompleted: {
        if (AirPCApiClient.isLoggedIn) {
            gameModelInstance.refresh()
        }
    }
}
