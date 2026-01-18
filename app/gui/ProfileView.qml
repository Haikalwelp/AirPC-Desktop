import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import AirPCApiClient 1.0

FocusScope {
    id: root
    objectName: qsTr("Profile")

    // Profile properties
    property string username: ""
    property string email: ""
    property int playtimeSeconds: 0
    property int claimCount: 0

    // Helper function to format playtime
    function formatPlaytime(seconds) {
        if (seconds < 0) seconds = 0
        var hours = Math.floor(seconds / 3600)
        var minutes = Math.floor((seconds % 3600) / 60)
        var secs = seconds % 60
        return hours.toString().padStart(2, '0') + ":" +
               minutes.toString().padStart(2, '0') + ":" +
               secs.toString().padStart(2, '0')
    }

    Component.onCompleted: {
        AirPCApiClient.fetchProfile()
    }

    Connections {
        target: AirPCApiClient
        function onProfileLoaded(playtimeSeconds, claimCount, username, email) {
            root.username = username || ""
            root.email = email || ""
            root.playtimeSeconds = playtimeSeconds || 0
            root.claimCount = claimCount || 0
        }
    }

    // Background
    Rectangle {
        id: background
        anchors.fill: parent
        color: "#1a1a2e"
    }

    // Main content
    ScrollView {
        anchors.fill: parent
        anchors.margins: 20
        contentWidth: availableWidth

        ColumnLayout {
            width: parent.width
            spacing: 24

            // Profile Header
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 120
                color: "#252542"
                radius: 12
                border.color: "#4a4a6a"
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 20

                    // Avatar placeholder
                    Rectangle {
                        Layout.preferredWidth: 80
                        Layout.preferredHeight: 80
                        radius: 40
                        color: "#6366f1"

                        Text {
                            anchors.centerIn: parent
                            text: root.username.length > 0 ? root.username.charAt(0).toUpperCase() : "?"
                            font.pixelSize: 32
                            font.bold: true
                            color: "#ffffff"
                        }
                    }

                    // User info
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 4

                        Item { Layout.fillHeight: true }

                        Text {
                            text: root.username || "Loading..."
                            font.pixelSize: 24
                            font.bold: true
                            color: "#ffffff"
                        }

                        Text {
                            text: root.email || ""
                            font.pixelSize: 14
                            color: "#a0a0b0"
                        }

                        Item { Layout.fillHeight: true }
                    }
                }
            }

            // Stats Cards
            RowLayout {
                Layout.fillWidth: true
                spacing: 16

                // Playtime Balance Card
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 140
                    color: "#1a3a2e"
                    radius: 12
                    border.color: "#22c55e"
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Rectangle {
                                width: 8
                                height: 8
                                radius: 4
                                color: "#22c55e"
                            }

                            Text {
                                text: qsTr("Playtime Balance")
                                font.pixelSize: 14
                                font.bold: true
                                color: "#22c55e"
                            }
                        }

                        Item { Layout.fillHeight: true }

                        Text {
                            text: formatPlaytime(root.playtimeSeconds)
                            font.pixelSize: 36
                            font.bold: true
                            font.family: "Consolas"
                            color: "#ffffff"
                        }

                        Text {
                            text: qsTr("Hours : Minutes : Seconds")
                            font.pixelSize: 12
                            color: "#a0a0b0"
                        }
                    }
                }

                // Orders Claimed Card
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 140
                    color: "#2a1a3e"
                    radius: 12
                    border.color: "#a855f7"
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Rectangle {
                                width: 8
                                height: 8
                                radius: 4
                                color: "#a855f7"
                            }

                            Text {
                                text: qsTr("Orders Claimed")
                                font.pixelSize: 14
                                font.bold: true
                                color: "#a855f7"
                            }
                        }

                        Item { Layout.fillHeight: true }

                        Text {
                            text: root.claimCount.toString()
                            font.pixelSize: 36
                            font.bold: true
                            color: "#ffffff"
                        }

                        Text {
                            text: qsTr("Total purchases")
                            font.pixelSize: 12
                            color: "#a0a0b0"
                        }
                    }
                }
            }

            // Spacer
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 40
            }

            // Sign Out Button
            Button {
                Layout.fillWidth: true
                Layout.preferredHeight: 50

                background: Rectangle {
                    color: parent.pressed ? "#dc2626" : (parent.hovered ? "#f87171" : "#ef4444")
                    radius: 8
                    border.color: "#ef4444"
                    border.width: 1

                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }
                }

                contentItem: Text {
                    text: qsTr("Sign Out")
                    font.pixelSize: 16
                    font.bold: true
                    color: "#ffffff"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: {
                    AirPCApiClient.logout()
                }
            }
        }
    }
}
