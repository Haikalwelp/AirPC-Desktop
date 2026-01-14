import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

import AirPCGameModel 1.0
import AirPCApiClient 1.0
import Session 1.0

Item {
    id: root
    objectName: "Game Library"

    // Design System Colors (matching Android/LoginScreen)
    readonly property color magenta: "#8A1C5C"
    readonly property color white: "#FFFFFF"
    readonly property color darkGray: "#454545"
    readonly property color glassWhite: Qt.rgba(1, 1, 1, 0.45)

    // State
    property string searchQuery: ""
    property bool searchExpanded: false
    property string selectedFilter: "All"

    // Signals
    signal streamLaunched(string sessionId, string streamHost, int streamPort, int httpsPort)
    signal logoutRequested()

    // ============================================================================
    // Inline Components (must be defined before use)
    // ============================================================================

    component FilterPill: Rectangle {
        id: pill
        
        property string text: ""
        property bool isSelected: false
        signal clicked()

        width: pillText.implicitWidth + 32
        height: 36
        radius: 22
        color: isSelected ? root.magenta : Qt.rgba(1, 1, 1, 0.1)
        border.color: isSelected ? root.magenta : Qt.rgba(0.27, 0.27, 0.27, 0.2)
        border.width: 1.5

        Behavior on color { ColorAnimation { duration: 150 } }

        Text {
            id: pillText
            anchors.centerIn: parent
            text: pill.text
            font.pixelSize: 14
            font.weight: Font.Medium
            font.family: "Montserrat"
            color: isSelected ? root.white : root.darkGray
        }

        MouseArea {
            anchors.fill: parent
            onClicked: pill.clicked()
            cursorShape: Qt.PointingHandCursor
        }
    }

    component GameCard: Item {
        id: card
        
        property string title: ""
        property string imageUrl: ""
        property string computerName: ""
        signal clicked()

        // Press animation
        property bool pressed: cardMouseArea.pressed
        scale: pressed ? 0.96 : 1.0
        Behavior on scale { NumberAnimation { duration: 100 } }

        ColumnLayout {
            anchors.fill: parent
            spacing: 10

            // Cover Art
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 12
                color: "#2A2A2A"
                clip: true

                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Qt.rgba(0, 0, 0, 0.25)
                    shadowVerticalOffset: 8
                    shadowBlur: 0.4
                }

                Image {
                    id: coverImage
                    anchors.fill: parent
                    source: card.imageUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true

                    // Placeholder while loading
                    Rectangle {
                        anchors.fill: parent
                        color: "#2A2A2A"
                        visible: coverImage.status !== Image.Ready
                    }

                    BusyIndicator {
                        anchors.centerIn: parent
                        running: coverImage.status === Image.Loading
                        visible: coverImage.status === Image.Loading
                        width: 32; height: 32
                    }
                }

                MouseArea {
                    id: cardMouseArea
                    anchors.fill: parent
                    onClicked: card.clicked()
                    cursorShape: Qt.PointingHandCursor
                }
            }

            // Title
            Text {
                Layout.fillWidth: true
                text: card.title
                font.pixelSize: 14
                font.weight: Font.SemiBold
                font.family: "Montserrat"
                color: root.white
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                maximumLineCount: 2
                wrapMode: Text.Wrap
            }
        }
    }

    component ActiveSessionCard: Rectangle {
        id: sessionCard
        
        property var session: null
        signal resumeClicked()
        signal endClicked()

        height: 80
        radius: 16
        color: Qt.rgba(1, 1, 1, 0.25)
        border.color: root.magenta
        border.width: 2

        RowLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 16

            // Session info
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: sessionCard.session ? sessionCard.session.appName : ""
                    font.pixelSize: 16
                    font.weight: Font.Bold
                    color: root.white
                }

                Text {
                    text: sessionCard.session ? "On " + sessionCard.session.computerName : ""
                    font.pixelSize: 12
                    color: Qt.rgba(1, 1, 1, 0.7)
                }
            }

            // Resume button
            Button {
                text: "Resume"
                
                contentItem: Text {
                    text: parent.text
                    color: root.white
                    font.pixelSize: 14
                    horizontalAlignment: Text.AlignHCenter
                }
                
                background: Rectangle {
                    color: root.magenta
                    radius: 8
                    implicitWidth: 80
                    implicitHeight: 36
                }

                onClicked: sessionCard.resumeClicked()
            }

            // End button
            Button {
                text: "End"
                
                contentItem: Text {
                    text: parent.text
                    color: root.darkGray
                    font.pixelSize: 14
                    horizontalAlignment: Text.AlignHCenter
                }
                
                background: Rectangle {
                    color: Qt.rgba(1, 1, 1, 0.3)
                    radius: 8
                    implicitWidth: 60
                    implicitHeight: 36
                }

                onClicked: sessionCard.endClicked()
            }
        }
    }

    // ============================================================================
    // Visual Elements
    // ============================================================================

    // Background Gradient
    Rectangle {
        id: background
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#DED1C6" }
            GradientStop { position: 0.33; color: "#A77693" }
            GradientStop { position: 0.66; color: "#174871" }
            GradientStop { position: 1.0; color: "#0F2D4D" }
        }
    }

    // Main Content
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 16

        // Header
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "Game Library"
                font.pixelSize: 24
                font.weight: Font.Bold
                font.family: "Montserrat"
                color: magenta
                font.letterSpacing: -0.5
            }

            Item { Layout.fillWidth: true }

            // User menu button
            ToolButton {
                id: userMenuBtn
                icon.source: "qrc:/res/settings.svg"
                icon.width: 24
                icon.height: 24
                
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

        // Search and Filter Bar
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: searchExpanded ? 120 : 56
            radius: 16
            color: Qt.rgba(1, 1, 1, 0.25)
            border.color: Qt.rgba(1, 1, 1, 0.15)
            border.width: 1

            Behavior on Layout.preferredHeight {
                NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                // Collapsed: Icon + Filters + Refresh
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    visible: !searchExpanded

                    // Search button
                    Rectangle {
                        width: 42; height: 42
                        radius: 12
                        color: Qt.rgba(1, 1, 1, 0.1)
                        border.color: Qt.rgba(0.27, 0.27, 0.27, 0.2)
                        border.width: 1

                        Image {
                            anchors.centerIn: parent
                            source: "qrc:/res/search.svg"
                            width: 20; height: 20
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: searchExpanded = true
                            cursorShape: Qt.PointingHandCursor
                        }
                    }

                    // Filter pills
                    Row {
                        spacing: 8
                        Repeater {
                            model: ["All", "Recent"]
                            delegate: FilterPill {
                                text: modelData
                                isSelected: selectedFilter === modelData
                                onClicked: selectedFilter = modelData
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Refresh button
                    ToolButton {
                        icon.source: "qrc:/res/refresh.svg"
                        icon.width: 20
                        icon.height: 20
                        onClicked: gameModelInstance.refresh()
                    }
                }

                // Expanded: Search field
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    visible: searchExpanded

                    TextField {
                        id: searchField
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        placeholderText: "Search games..."
                        font.pixelSize: 14
                        leftPadding: 44
                        rightPadding: 44

                        background: Rectangle {
                            color: Qt.rgba(1, 1, 1, 0.3)
                            border.color: searchField.activeFocus ? magenta : Qt.rgba(0.27, 0.27, 0.27, 0.2)
                            border.width: 1
                            radius: 12
                        }

                        Image {
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            source: "qrc:/res/search.svg"
                            width: 20; height: 20
                        }

                        ToolButton {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            icon.source: "qrc:/res/close.svg"
                            icon.width: 20
                            icon.height: 20
                            onClicked: {
                                searchField.text = ""
                                searchExpanded = false
                            }
                        }

                        onTextChanged: searchQuery = text
                    }

                    // Filters row when expanded
                    RowLayout {
                        Layout.fillWidth: true

                        Row {
                            spacing: 8
                            Repeater {
                                model: ["All", "Recent"]
                                delegate: FilterPill {
                                    text: modelData
                                    isSelected: selectedFilter === modelData
                                    onClicked: selectedFilter = modelData
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        ToolButton {
                            icon.source: "qrc:/res/refresh.svg"
                            icon.width: 20
                            icon.height: 20
                            onClicked: gameModelInstance.refresh()
                        }
                    }
                }
            }
        }

        // Active Session Card (if any)
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

            // Loading State
            BusyIndicator {
                anchors.centerIn: parent
                running: gameModelInstance.loading
                visible: gameModelInstance.loading && gameGrid.count === 0
                width: 48; height: 48
            }

            // Empty State
            ColumnLayout {
                anchors.centerIn: parent
                visible: !gameModelInstance.loading && gameGrid.count === 0
                spacing: 8

                Text {
                    text: gameModelInstance.errorMessage !== "" ? "Oops! Something went wrong" : "No Games Available"
                    font.pixelSize: 20
                    font.weight: Font.Bold
                    color: white
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    text: gameModelInstance.errorMessage !== "" ? gameModelInstance.errorMessage : "You don't have any active game allocations yet."
                    font.pixelSize: 14
                    color: Qt.rgba(1, 1, 1, 0.7)
                    Layout.alignment: Qt.AlignHCenter
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    Layout.maximumWidth: 300
                }

                Button {
                    text: "Retry"
                    visible: gameModelInstance.errorMessage !== ""
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 16
                    
                    contentItem: Text {
                        text: parent.text
                        color: white
                        font.pixelSize: 14
                        horizontalAlignment: Text.AlignHCenter
                    }
                    
                    background: Rectangle {
                        color: magenta
                        radius: 8
                        implicitWidth: 100
                        implicitHeight: 40
                    }

                    onClicked: gameModelInstance.refresh()
                }
            }

            // Game Grid
            GridView {
                id: gameGrid
                anchors.fill: parent
                visible: gameGrid.count > 0

                cellWidth: 180
                cellHeight: 280
                clip: true

                model: AirPCGameSortFilterModel {
                    id: sortFilterModel
                    sourceModel: gameModelInstance
                    filterText: searchQuery
                }

                delegate: GameCard {
                    width: gameGrid.cellWidth - 16
                    height: gameGrid.cellHeight - 16
                    
                    title: model.title
                    imageUrl: model.imageUrl
                    computerName: model.computerName
                    
                    onClicked: {
                        console.log("Launching game:", model.title)
                        sortFilterModel.launchGame(index)
                    }
                }

                // Scroll behavior
                ScrollBar.vertical: ScrollBar { 
                    policy: ScrollBar.AsNeeded 
                }
            }
        }
    }

    // Error Dialog
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
            // Stream ended - user returned from streaming session
            // The view will remain on the game library
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
