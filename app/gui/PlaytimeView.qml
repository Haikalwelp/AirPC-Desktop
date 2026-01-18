import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import AirPCApiClient 1.0

Item {
    id: playtimeView
    
    // Refresh profile on load
    Component.onCompleted: {
        AirPCApiClient.fetchProfile()
        AirPCApiClient.fetchClaimHistory()
    }
    
    // State
    property int playtimeSeconds: 0
    property int claimCount: 0
    property var claimHistory: []
    property string claimError: ""
    property bool claiming: false
    
    // Connect signals
    Connections {
        target: AirPCApiClient
        
        function onProfileLoaded(playtimeSeconds, claimCount, username, email) {
            playtimeView.playtimeSeconds = playtimeSeconds
            playtimeView.claimCount = claimCount
        }
        
        function onClaimSucceeded(granted, total) {
            playtimeView.playtimeSeconds = total
            playtimeView.claiming = false
            orderInput.text = ""
            claimError = ""
            AirPCApiClient.fetchClaimHistory()
        }
        
        function onClaimFailed(error) {
            playtimeView.claiming = false
            playtimeView.claimError = error
        }
        
        function onClaimHistoryReceived(claims) {
            playtimeView.claimHistory = claims
        }
    }
    
    // Format helper
    function formatPlaytime(seconds) {
        if (seconds <= 0) return "0m"
        var hours = Math.floor(seconds / 3600)
        var minutes = Math.floor((seconds % 3600) / 60)
        if (hours > 0 && minutes > 0) return hours + "h " + minutes + "m"
        if (hours > 0) return hours + "h"
        return minutes + "m"
    }
    
    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        
        ColumnLayout {
            width: parent.width
            spacing: 24
            
            // Balance Card
            Rectangle {
                Layout.fillWidth: true
                Layout.margins: 16
                height: 120
                radius: 12
                color: "#1a1a2e"
                border.color: "#4a4a6a"
                border.width: 1
                
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 8
                    
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Your Playtime Balance"
                        color: "#888"
                        font.pixelSize: 14
                    }
                    
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: formatPlaytime(playtimeSeconds)
                        color: "#fff"
                        font.pixelSize: 36
                        font.bold: true
                    }
                    
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: claimCount + " orders claimed"
                        color: "#666"
                        font.pixelSize: 12
                    }
                }
            }
            
            // Claim Order Section
            Rectangle {
                Layout.fillWidth: true
                Layout.margins: 16
                height: claimColumn.height + 32
                radius: 12
                color: "#1a1a2e"
                border.color: "#4a4a6a"
                border.width: 1
                
                ColumnLayout {
                    id: claimColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 16
                    spacing: 12
                    
                    Text {
                        text: "Claim Shopee Order"
                        color: "#fff"
                        font.pixelSize: 18
                        font.bold: true
                    }
                    
                    Text {
                        Layout.fillWidth: true
                        text: "Enter your Shopee order number to receive 2 hours of playtime."
                        color: "#888"
                        font.pixelSize: 13
                        wrapMode: Text.WordWrap
                    }
                    
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        
                        TextField {
                            id: orderInput
                            Layout.fillWidth: true
                            placeholderText: "e.g., 241230ABCD1234"
                            color: "#fff"
                            placeholderTextColor: "#666"
                            background: Rectangle {
                                color: "#0d0d1a"
                                radius: 6
                                border.color: orderInput.focus ? "#6366f1" : "#333"
                            }
                        }
                        
                        Button {
                            text: claiming ? "Claiming..." : "Claim"
                            enabled: orderInput.text.length > 0 && !claiming
                            onClicked: {
                                claiming = true
                                claimError = ""
                                AirPCApiClient.claimOrder(orderInput.text.trim())
                            }
                            
                            background: Rectangle {
                                color: parent.enabled ? "#6366f1" : "#333"
                                radius: 6
                            }
                            
                            contentItem: Text {
                                text: parent.text
                                color: parent.enabled ? "#fff" : "#666"
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }
                    
                    // Error message
                    Text {
                        visible: claimError.length > 0
                        text: claimError
                        color: "#ef4444"
                        font.pixelSize: 13
                    }
                }
            }
            
            // Claim History Section
            Rectangle {
                Layout.fillWidth: true
                Layout.margins: 16
                height: historyColumn.height + 32
                radius: 12
                color: "#1a1a2e"
                border.color: "#4a4a6a"
                border.width: 1
                
                ColumnLayout {
                    id: historyColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 16
                    spacing: 12
                    
                    Text {
                        text: "Claim History"
                        color: "#fff"
                        font.pixelSize: 18
                        font.bold: true
                    }
                    
                    // Empty state
                    Text {
                        visible: claimHistory.length === 0
                        text: "No claims yet"
                        color: "#666"
                        font.pixelSize: 13
                    }
                    
                    // History list
                    Repeater {
                        model: claimHistory
                        
                        Rectangle {
                            Layout.fillWidth: true
                            height: 48
                            color: "#0d0d1a"
                            radius: 6
                            
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                
                                Text {
                                    text: modelData.orderSn || ""
                                    color: "#fff"
                                    font.pixelSize: 14
                                }
                                
                                Item { Layout.fillWidth: true }
                                
                                Text {
                                    text: "+" + formatPlaytime(modelData.playtimeGranted || 0)
                                    color: "#22c55e"
                                    font.pixelSize: 14
                                    font.bold: true
                                }
                            }
                        }
                    }
                }
            }
            
            // Spacer
            Item { Layout.fillHeight: true }
        }
    }
}
