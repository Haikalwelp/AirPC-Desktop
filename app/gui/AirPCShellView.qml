import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/*
  Top-level navigation shell.
  Keeps tab pages alive (loaded once), and switches tabs without growing the StackView.
*/
Item {
    id: shell
    objectName: "Shell"

    // Set by Router when first creating the Shell
    property string initialTab: "games"

    // Current active tab name
    property string currentTab: "games"

    function tabToIndex(tab) {
        switch (tab) {
        case "games": return 0
        case "profile": return 1
        case "settings": return 2
        case "playtime": return 3
        default: return 0
        }
    }

    onInitialTabChanged: {
        if (initialTab !== "") {
            currentTab = initialTab
        }
    }

    onCurrentTabChanged: {
        stack.currentIndex = tabToIndex(currentTab)
    }

    Component.onCompleted: {
        stack.currentIndex = tabToIndex(currentTab)
    }

    StackLayout {
        id: stack
        anchors.fill: parent

        // Games
        Loader {
            id: gamesLoader
            property bool keepLoaded: false
            active: keepLoaded || shell.currentTab === "games"
            source: "qrc:/gui/AirPCPublicGamesView.qml"
            onLoaded: {
                keepLoaded = true
                item.anchors.fill = parent
            }
        }

        // Profile
        Loader {
            id: profileLoader
            property bool keepLoaded: false
            active: keepLoaded || shell.currentTab === "profile"
            source: "qrc:/gui/ProfileView.qml"
            onLoaded: {
                keepLoaded = true
                item.anchors.fill = parent
            }
        }

        // Settings
        Loader {
            id: settingsLoader
            property bool keepLoaded: false
            active: keepLoaded || shell.currentTab === "settings"
            source: "qrc:/gui/SettingsView.qml"
            onLoaded: {
                keepLoaded = true
                item.anchors.fill = parent
            }
        }

        // Playtime
        Loader {
            id: playtimeLoader
            property bool keepLoaded: false
            active: keepLoaded || shell.currentTab === "playtime"
            source: "qrc:/gui/PlaytimeView.qml"
            onLoaded: {
                keepLoaded = true
                item.anchors.fill = parent
            }
        }
    }
}
