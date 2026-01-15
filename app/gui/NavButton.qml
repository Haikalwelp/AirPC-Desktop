import QtQuick 2.9
import QtQuick.Controls 2.2

import "." as App

/**
 * Navigation button with pill-shaped styling matching AirPC web design.
 */
Button {
    id: navButton

    // ============================================================================
    // Properties
    // ============================================================================

    property string route: ""
    property string label: ""
    readonly property bool isActive: App.Router.currentTab === route

    // Design constants (hardcoded for reliability)
    readonly property color primaryColor: "#8A1C5C"
    readonly property color primaryHover: Qt.rgba(138/255, 28/255, 92/255, 0.1)
    readonly property color textPrimaryColor: "#454545"
    readonly property color textOnPrimaryColor: "#FFFFFF"

    // ============================================================================
    // Button Configuration
    // ============================================================================

    text: label
    flat: true
    activeFocusOnTab: true

    implicitWidth: contentItem.implicitWidth + 40
    implicitHeight: contentItem.implicitHeight + 20

    // ============================================================================
    // Background Styling
    // ============================================================================

    background: Rectangle {
        id: backgroundRect

        radius: 22
        color: {
            if (isActive) {
                return primaryColor
            } else if (navButton.hovered || navButton.activeFocus) {
                return primaryHover
            } else {
                return "transparent"
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }
    }

    // ============================================================================
    // Content Styling
    // ============================================================================

    contentItem: Text {
        text: navButton.text
        font.pixelSize: 14
        font.weight: Font.Medium
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter

        color: {
            if (isActive) {
                return textOnPrimaryColor
            } else if (navButton.hovered || navButton.activeFocus) {
                return primaryColor
            } else {
                return textPrimaryColor
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }
    }

    // ============================================================================
    // Behavior
    // ============================================================================

    onClicked: {
        if (route !== "") {
            App.Router.switchTab(route)
        }
    }

    // ============================================================================
    // Keyboard Navigation
    // ============================================================================

    Keys.onReturnPressed: {
        clicked()
    }

    Keys.onEnterPressed: {
        clicked()
    }

    Keys.onRightPressed: {
        nextItemInFocusChain(true).forceActiveFocus(Qt.TabFocus)
    }

    Keys.onLeftPressed: {
        nextItemInFocusChain(false).forceActiveFocus(Qt.TabFocus)
    }

    // ============================================================================
    // ToolTip
    // ============================================================================

    ToolTip.visible: hovered
    ToolTip.text: label
    ToolTip.delay: 500
}
