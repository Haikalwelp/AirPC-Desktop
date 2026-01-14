import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

FocusScope {
    id: root
    objectName: qsTr("Playtime")

    // Background Gradient matching AirPCLoginView style
    Rectangle {
        id: background
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: "#DED1C6" }
            GradientStop { position: 0.33; color: "#A77693" }
            GradientStop { position: 0.66; color: "#174871" }
            GradientStop { position: 1.0; color: "#0F2D4D" }
        }
    }

    // Centered content
    ColumnLayout {
        anchors.centerIn: parent
        spacing: 12

        Text {
            text: "Playtime"
            font.pointSize: 28
            font.bold: true
            color: "#FFFFFF"
            Layout.alignment: Qt.AlignHCenter
        }

        Text {
            text: "Coming soon"
            font.pointSize: 16
            color: "#FFFFFF"
            opacity: 0.7
            Layout.alignment: Qt.AlignHCenter
        }
    }
}
