import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "." as App

/**
 * GlassCard - Glassmorphism card component matching web client design.
 *
 * Usage:
 *   GlassCard {
 *       title: "Card Title"
 *       ColumnLayout {
 *           // card content
 *       }
 *   }
 */
Rectangle {
    id: root

    // Optional card title
    property string title: ""

    // Content item - use default property for children
    default property alias content: contentContainer.data

    // Sizing
    property int cardPadding: App.AirPCTheme.glassPadding

    // Glass styling from theme
    color: App.AirPCTheme.glassBackground
    radius: App.AirPCTheme.glassRadius
    border.color: App.AirPCTheme.glassBorder
    border.width: App.AirPCTheme.glassBorderWidth

    // Subtle shadow effect
    layer.enabled: true
    layer.effect: Item {
        // Simple shadow using nested rectangle
    }

    // Drop shadow simulation
    Rectangle {
        id: shadow
        anchors.fill: parent
        anchors.margins: -1
        z: -1
        radius: parent.radius + 1
        color: "transparent"
        border.color: "transparent"

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 8
            radius: parent.radius
            color: Qt.rgba(0, 0, 0, 0.1)
            z: -2
        }
    }

    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.margins: root.cardPadding
        spacing: 16

        // Card title (optional)
        Text {
            id: titleText
            visible: root.title.length > 0
            text: root.title
            font.pixelSize: App.AirPCTheme.cardTitleSize
            font.weight: Font.DemiBold
            font.family: App.AirPCTheme.fontFamily
            color: App.AirPCTheme.textPrimary
            Layout.fillWidth: true
        }

        // Content container
        Item {
            id: contentContainer
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
