import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3
import QtQuick.Window 2.2
import QtQuick.Controls.Material 2.2

import ComputerManager 1.0
import AutoUpdateChecker 1.0
import StreamingPreferences 1.0
import SystemProperties 1.0
import SdlGamepadKeyNavigation 1.0
import AirPCApiClient 1.0
import "." as App

ApplicationWindow {
    property bool pollingActive: false

    // Set by SettingsView to force the back operation to pop all
    // pages except the initial view. This is required when doing
    // a retranslate() because AppView breaks for some reason.
    property bool clearOnBack: false

    id: window
    width: 1280
    height: 600

    // This function runs prior to creation of the initial StackView item
    function doEarlyInit() {
        // Override the background color to Material 2 colors for Qt 6.5+
        // in order to improve contrast between GFE's placeholder box art
        // and the background of the app grid.
        if (SystemProperties.usesMaterial3Theme) {
            Material.background = "#303030"
        }

        SdlGamepadKeyNavigation.enable()
    }

    Component.onCompleted: {
        // Show the window according to the user's preferences
        if (SystemProperties.hasDesktopEnvironment) {
            if (StreamingPreferences.uiDisplayMode == StreamingPreferences.UI_MAXIMIZED) {
                window.showMaximized()
            }
            else if (StreamingPreferences.uiDisplayMode == StreamingPreferences.UI_FULLSCREEN) {
                window.showFullScreen()
            }
            else {
                window.show()
            }
        } else {
            window.showFullScreen()
        }

        // Display any modal dialogs for configuration warnings
        if (SystemProperties.isWow64) {
            wow64Dialog.open()
        }
        else if (!SystemProperties.hasHardwareAcceleration && StreamingPreferences.videoDecoderSelection !== StreamingPreferences.VDS_FORCE_SOFTWARE) {
            if (SystemProperties.isRunningXWayland) {
                xWaylandDialog.open()
            }
            else {
                noHwDecoderDialog.open()
            }
        }

        if (SystemProperties.unmappedGamepads) {
            unmappedGamepadDialog.unmappedGamepads = SystemProperties.unmappedGamepads
            unmappedGamepadDialog.open()
        }
    }
  
    // It would be better to use TextMetrics here, but it always lays out
    // the text slightly more compactly than real Text does in ToolTip,
    // causing unexpected line breaks to be inserted
    Text {
        id: tooltipTextLayoutHelper
        visible: false
        font: ToolTip.toolTip.font
        text: ToolTip.toolTip.text
    }

    // This configures the maximum width of the singleton attached QML ToolTip. If left unconstrained,
    // it will never insert a line break and just extend on forever.
    // Note: ToolTip must be attached to an Item, not ApplicationWindow
    Item {
        id: tooltipHelper
        ToolTip.toolTip.contentWidth: Math.min(tooltipTextLayoutHelper.width, 400)
    }

    function goBack() {
        if (clearOnBack) {
            stackView.pop(null)
            clearOnBack = false
        }
        else {
            App.Router.back()
        }
    }

    StackView {
        id: stackView
        anchors.fill: parent
        focus: true

        Component.onCompleted: {
            // Perform our early initialization
            doEarlyInit()

            // Initialize Router with StackView reference
            App.Router.stackView = stackView
            App.Router.init()
        }

        onCurrentItemChanged: {
            // Ensure focus travels to the next view when going back
            if (currentItem) {
                currentItem.forceActiveFocus()
            }
        }

        Keys.onEscapePressed: {
            if (depth > 1) {
                goBack()
            }
            else {
                quitConfirmationDialog.open()
            }
        }

        Keys.onBackPressed: {
            if (depth > 1) {
                goBack()
            }
            else {
                quitConfirmationDialog.open()
            }
        }

        Keys.onMenuPressed: {
            settingsButton.clicked()
        }

        // This is a keypress we've reserved for letting the
        // SdlGamepadKeyNavigation object tell us to show settings
        // when Menu is consumed by a focused control.
        Keys.onHangupPressed: {
            settingsButton.clicked()
        }
    }

    // Router logout handler
    Connections {
        target: AirPCApiClient
        function onLogoutCompleted() {
            App.Router.onLogout()
        }
    }

    // This timer keeps us polling for 5 minutes of inactivity
    // to allow the user to work with Moonlight on a second display
    // while dealing with configuration issues. This will ensure
    // machines come online even if the input focus isn't on Moonlight.
    Timer {
        id: inactivityTimer
        interval: 5 * 60000
        onTriggered: {
            if (!active && pollingActive) {
                ComputerManager.stopPollingAsync()
                pollingActive = false
            }
        }
    }

    onVisibleChanged: {
        // When we become invisible while streaming is going on,
        // stop polling immediately.
        if (!visible) {
            inactivityTimer.stop()

            if (pollingActive) {
                ComputerManager.stopPollingAsync()
                pollingActive = false
            }
        }
        else if (active) {
            // When we become visible and active again, start polling
            inactivityTimer.stop()

            // Restart polling if it was stopped
            if (!pollingActive) {
                ComputerManager.startPolling()
                pollingActive = true
            }
        }

        // Poll for gamepad input only when the window is in focus
        SdlGamepadKeyNavigation.notifyWindowFocus(visible && active)
    }

    onActiveChanged: {
        if (active) {
            // Stop the inactivity timer
            inactivityTimer.stop()

            // Restart polling if it was stopped
            if (!pollingActive) {
                ComputerManager.startPolling()
                pollingActive = true
            }
        }
        else {
            // Start the inactivity timer to stop polling
            // if focus does not return within a few minutes.
            inactivityTimer.restart()
        }

        // Poll for gamepad input only when the window is in focus
        SdlGamepadKeyNavigation.notifyWindowFocus(visible && active)
    }

    // Workaround for lack of instanceof in Qt 5.9.
    //
    // Based on https://stackoverflow.com/questions/13923794/how-to-do-a-is-a-typeof-or-instanceof-in-qml
    function qmltypeof(obj, className) { // QtObject, string -> bool
        // className plus "(" is the class instance without modification
        // className plus "_QML" is the class instance with user-defined properties
        var str = obj.toString();
        return str.startsWith(className + "(") || str.startsWith(className + "_QML");
    }

    function navigateTo(url, objectType)
    {
        var existingItem = stackView.find(function(item, index) {
            return qmltypeof(item, objectType)
        })

        if (existingItem !== null) {
            // Pop to the existing item
            stackView.pop(existingItem)
        }
        else {
            // Create a new item
            stackView.push(url)
        }
    }

    header: ToolBar {
        id: toolBar
        height: 60

        // Custom gradient background matching web design
        background: Rectangle {
            color: "#DED1C6"

            // Bottom border
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: "#FFFFFF"
                opacity: 0.3
            }
        }

        RowLayout {
            spacing: 24
            anchors.leftMargin: 32
            anchors.rightMargin: 32
            anchors.fill: parent

            // Left section: Back button + Logo
            Row {
                spacing: 16

                // Back button
                NavigableToolButton {
                    visible: stackView.depth > 1
                    iconSource: "qrc:/res/arrow_left.svg"

                    onClicked: goBack()

                    Keys.onDownPressed: {
                        stackView.currentItem.forceActiveFocus(Qt.TabFocus)
                    }
                }

                // Logo/Brand
                Label {
                    id: logoLabel
                    text: "AirPC"
                    font.pixelSize: 24
                    font.weight: Font.DemiBold
                    color: "#8A1C5C"
                    verticalAlignment: Qt.AlignVCenter
                    anchors.verticalCenter: parent.verticalCenter

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (AirPCApiClient.isLoggedIn) {
                                App.Router.switchTab("games")
                            }
                        }
                    }
                }
            }

            // Spacer
            Item {
                Layout.fillWidth: true
            }

            // Navigation buttons (visible only when logged in)
            Row {
                visible: AirPCApiClient.isLoggedIn
                spacing: 8

                NavButton {
                    route: "games"
                    label: qsTr("Games")
                }

                NavButton {
                    route: "profile"
                    label: qsTr("Profile")
                }

                NavButton {
                    route: "settings"
                    label: qsTr("Settings")
                }

                NavButton {
                    route: "playtime"
                    label: qsTr("Playtime")
                }
            }

            // User section separator and content (visible only when logged in)
            Rectangle {
                visible: AirPCApiClient.isLoggedIn
                width: 1.5
                height: 28
                color: Qt.rgba(69/255, 69/255, 69/255, 0.15)
                Layout.alignment: Qt.AlignVCenter
            }

            Row {
                visible: AirPCApiClient.isLoggedIn
                spacing: 16
                Layout.alignment: Qt.AlignVCenter

                // Username link
                Label {
                    id: usernameLabel
                    text: AirPCApiClient.username
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    color: "#8A1C5C"
                    verticalAlignment: Qt.AlignVCenter
                    anchors.verticalCenter: parent.verticalCenter

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: App.Router.switchTab("profile")
                        onEntered: usernameLabel.opacity = 0.7
                        onExited: usernameLabel.opacity = 1.0
                    }

                    Behavior on opacity {
                        NumberAnimation { duration: 150 }
                    }
                }

                // Logout button
                Button {
                    id: logoutButton
                    text: qsTr("Logout")
                    flat: true
                    anchors.verticalCenter: parent.verticalCenter

                    contentItem: Text {
                        text: logoutButton.text
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        color: logoutButton.hovered ? "#d63636" : "#F94141"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter

                        Behavior on color {
                            ColorAnimation { duration: 150 }
                        }
                    }

                    background: Rectangle {
                        radius: 12
                        color: logoutButton.hovered ? Qt.rgba(249/255, 65/255, 65/255, 0.1) : "transparent"

                        Behavior on color {
                            ColorAnimation { duration: 150 }
                        }
                    }

                    onClicked: AirPCApiClient.logout()

                    ToolTip.delay: 1000
                    ToolTip.timeout: 3000
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("Logout")

                    Keys.onDownPressed: {
                        stackView.currentItem.forceActiveFocus(Qt.TabFocus)
                    }
                }
            }

            // Update button (visible when update is available)
            NavigableToolButton {
                property string browserUrl: ""

                id: updateButton

                iconSource: "qrc:/res/update.svg"

                ToolTip.delay: 1000
                ToolTip.timeout: 3000
                ToolTip.visible: hovered || visible

                // Invisible until we get a callback notifying us that
                // an update is available
                visible: false

                onClicked: {
                    if (SystemProperties.hasBrowser) {
                        Qt.openUrlExternally(browserUrl);
                    }
                }

                function updateAvailable(version, url)
                {
                    ToolTip.text = qsTr("Update available for Artemis: Version %1").arg(version)
                    updateButton.browserUrl = url
                    updateButton.visible = true
                }

                Component.onCompleted: {
                    AutoUpdateChecker.onUpdateAvailable.connect(updateAvailable)
                    AutoUpdateChecker.start()
                }

                Keys.onDownPressed: {
                    stackView.currentItem.forceActiveFocus(Qt.TabFocus)
                }
            }

            // Help button (always visible)
            NavigableToolButton {
                id: helpButton
                visible: SystemProperties.hasBrowser

                iconSource: "qrc:/res/question_mark.svg"

                ToolTip.delay: 1000
                ToolTip.timeout: 3000
                ToolTip.visible: hovered
                ToolTip.text: qsTr("Help") + (helpShortcut.nativeText ? (" ("+helpShortcut.nativeText+")") : "")

                Shortcut {
                    id: helpShortcut
                    sequence: StandardKey.HelpContents
                    onActivated: helpButton.clicked()
                }

                // TODO need to make sure browser is brought to foreground.
                onClicked: Qt.openUrlExternally("https://github.com/wjbeckett/artemis/wiki/Setup-Guide");

                Keys.onDownPressed: {
                    stackView.currentItem.forceActiveFocus(Qt.TabFocus)
                }
            }

            // Settings button (fallback, visible only when NOT logged in)
            NavigableToolButton {
                id: settingsButton
                visible: !AirPCApiClient.isLoggedIn

                iconSource: "qrc:/res/settings.svg"

                onClicked: navigateTo("qrc:/gui/SettingsView.qml", "SettingsView")

                Keys.onDownPressed: {
                    stackView.currentItem.forceActiveFocus(Qt.TabFocus)
                }

                Shortcut {
                    id: settingsShortcut
                    sequence: StandardKey.Preferences
                    onActivated: settingsButton.clicked()
                }

                ToolTip.delay: 1000
                ToolTip.timeout: 3000
                ToolTip.visible: hovered
                ToolTip.text: qsTr("Settings") + (settingsShortcut.nativeText ? (" ("+settingsShortcut.nativeText+")") : "")
            }
        }
    }

    ErrorMessageDialog {
        id: noHwDecoderDialog
        text: qsTr("No functioning hardware accelerated video decoder was detected by Artemis. " +
                   "Your streaming performance may be severely degraded in this configuration.")
        helpText: qsTr("Click the Help button for more information on solving this problem.")
        helpUrl: "https://github.com/wjbeckett/artemis/wiki/Fixing-Hardware-Decoding-Problems"
    }

    ErrorMessageDialog {
        id: xWaylandDialog
        text: qsTr("Hardware acceleration doesn't work on XWayland. Continuing on XWayland may result in poor streaming performance. " +
                   "Try running with QT_QPA_PLATFORM=wayland or switch to X11.")
        helpText: qsTr("Click the Help button for more information.")
        helpUrl: "https://github.com/wjbeckett/artemis/wiki/Fixing-Hardware-Decoding-Problems"
    }

    NavigableMessageDialog {
        id: wow64Dialog
        standardButtons: Dialog.Ok | Dialog.Cancel
        text: qsTr("This version of Artemis isn't optimized for your PC. Please download the '%1' version of Artemis for the best streaming performance.").arg(SystemProperties.friendlyNativeArchName)
        onAccepted: {
            Qt.openUrlExternally("https://github.com/wjbeckett/artemis/releases");
        }
    }

    ErrorMessageDialog {
        id: unmappedGamepadDialog
        property string unmappedGamepads : ""
        text: qsTr("Artemis detected gamepads without a mapping:") + "\n" + unmappedGamepads
        helpTextSeparator: "\n\n"
        helpText: qsTr("Click the Help button for information on how to map your gamepads.")
        helpUrl: "https://github.com/wjbeckett/artemis/wiki/Gamepad-Mapping"
    }

    // This dialog appears when quitting via keyboard or gamepad button
    NavigableMessageDialog {
        id: quitConfirmationDialog
        standardButtons: Dialog.Yes | Dialog.No
        text: qsTr("Are you sure you want to quit?")
        // For keyboard/gamepad navigation
        onAccepted: Qt.quit()
    }

    // HACK: This belongs in StreamSegue but keeping a dialog around after the parent
    // dies can trigger bugs in Qt 5.12 that cause the app to crash. For now, we will
    // host this dialog in a QML component that is never destroyed.
    //
    // To repro: Start a stream, cut the network connection to trigger the "Connection
    // terminated" dialog, wait until the app grid times out back to the PC grid, then
    // try to dismiss the dialog.
    ErrorMessageDialog {
        id: streamSegueErrorDialog

        property bool quitAfter: false

        onClosed: {
            if (quitAfter) {
                Qt.quit()
            }

            // StreamSegue assumes its dialog will be re-created each time we
            // start streaming, so fake it by wiping out the text each time.
            text = ""
        }
    }

    NavigableDialog {
        id: addPcDialog
        property string label: qsTr("Enter the IP address of your host PC:")

        standardButtons: Dialog.Ok | Dialog.Cancel

        onOpened: {
            // Force keyboard focus on the textbox so keyboard navigation works
            editText.forceActiveFocus()
        }

        onClosed: {
            editText.clear()
        }

        onAccepted: {
            if (editText.text) {
                ComputerManager.addNewHostManually(editText.text.trim())
            }
        }

        ColumnLayout {
            Label {
                text: addPcDialog.label
                font.bold: true
            }

            TextField {
                id: editText
                Layout.fillWidth: true
                focus: true

                Keys.onReturnPressed: {
                    addPcDialog.accept()
                }

                Keys.onEnterPressed: {
                    addPcDialog.accept()
                }
            }
        }
    }
}
