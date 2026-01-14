import QtQuick
import QtQuick.Controls

import "." as App

NavigableToolButton {
    id: navButton

    // ============================================================================
    // Properties
    // ============================================================================

    // The route name to navigate to (e.g., "games", "settings", "profile")
    property string route: ""

    // Display text for the button
    property string label: ""

    // ============================================================================
    // Bindings
    // ============================================================================

    text: label
    highlighted: App.Router.currentRoute === route

    // ============================================================================
    // Behavior
    // ============================================================================

    onClicked: {
        if (route !== "") {
            App.Router.push(route)
        }
    }

    // ============================================================================
    // ToolTip
    // ============================================================================

    ToolTip.visible: hovered
    ToolTip.text: label
    ToolTip.delay: 500
}
