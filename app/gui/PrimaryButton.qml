import QtQuick 2.15
import QtQuick.Controls 2.15
import "." as App

/**
 * PrimaryButton - Styled button matching web client design.
 *
 * Features:
 *   - Pill-shaped (rounded ends)
 *   - Primary brand color (#8A1C5C)
 *   - Hover lift effect
 *   - Shadow on hover
 *
 * Usage:
 *   PrimaryButton {
 *       text: "Proceed to Payment"
 *       onClicked: startCheckout()
 *   }
 */
Button {
    id: root

    property bool loading: false

    implicitHeight: App.AirPCTheme.buttonHeight
    enabled: !loading

    contentItem: Text {
        text: root.loading ? qsTr("Loading...") : root.text
        font.pixelSize: App.AirPCTheme.buttonFontSize
        font.weight: Font.Medium
        font.family: App.AirPCTheme.fontFamily
        color: App.AirPCTheme.textOnPrimary
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        opacity: root.enabled ? 1.0 : 0.6
    }

    background: Rectangle {
        id: bgRect
        radius: App.AirPCTheme.buttonRadius
        color: {
            if (!root.enabled) return Qt.rgba(138/255, 28/255, 92/255, 0.5)
            if (root.pressed) return App.AirPCTheme.primaryPressed
            if (root.hovered) return App.AirPCTheme.primaryHover
            return App.AirPCTheme.primary
        }

        // Shadow
        Rectangle {
            id: shadowRect
            anchors.fill: parent
            anchors.topMargin: root.hovered && root.enabled ? 4 : 2
            z: -1
            radius: parent.radius
            color: App.AirPCTheme.primaryShadow
            visible: root.enabled
        }

        // Lift effect on hover
        transform: Translate {
            y: root.hovered && root.enabled && !root.pressed ? -2 : 0

            Behavior on y {
                NumberAnimation { duration: App.AirPCTheme.transitionDuration }
            }
        }

        Behavior on color {
            ColorAnimation { duration: App.AirPCTheme.transitionDuration }
        }
    }
}
