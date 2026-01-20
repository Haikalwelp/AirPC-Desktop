import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtWebEngine
import AirPCApiClient 1.0
import "." as App

/**
 * PlaytimeView - Embedded web client for playtime purchase.
 *
 * Uses WebEngineView to load the web client's playtime page,
 * providing 100% feature parity including Adyen payment support.
 */
Item {
    id: root
    objectName: qsTr("Playtime")

    // State
    property string embedToken: ""
    property bool isLoading: true
    property bool hasError: false
    property string errorMessage: ""
    property bool pageLoaded: false

    // Allowed URL patterns for navigation
    readonly property var allowedDomains: [
        "airpc.co",
        "airpc.my",
        "adyen.com",
        "touchngo.com.my",
        "fpx.com.my"
    ]

    // Request embed token on load
    Component.onCompleted: {
        requestEmbedToken()
    }

    function requestEmbedToken() {
        isLoading = true
        hasError = false
        errorMessage = ""
        pageLoaded = false
        AirPCApiClient.createEmbedToken()
    }

    function isAllowedUrl(url) {
        var urlStr = url.toString().toLowerCase()
        for (var i = 0; i < allowedDomains.length; i++) {
            if (urlStr.indexOf(allowedDomains[i]) !== -1) {
                return true
            }
        }
        return false
    }

    // Check if URL is an allowed path within AirPC (only /playtime pages)
    function isAllowedPlaytimePath(url) {
        var urlStr = url.toString().toLowerCase()
        
        // Allow playtime paths on airpc domains
        if (urlStr.indexOf("airpc.co") !== -1 || urlStr.indexOf("airpc.my") !== -1) {
            // Only allow /playtime and /playtime/receipt paths
            if (urlStr.indexOf("/playtime") !== -1) {
                return true
            }
            return false
        }
        
        // Allow payment provider domains (Adyen, FPX, TNG, etc.)
        var paymentDomains = ["adyen.com", "touchngo.com.my", "fpx.com.my", "maybank2u.com.my", "cimbclicks.com.my"]
        for (var i = 0; i < paymentDomains.length; i++) {
            if (urlStr.indexOf(paymentDomains[i]) !== -1) {
                return true
            }
        }
        
        return false
    }

    // API connections
    Connections {
        target: AirPCApiClient

        function onEmbedTokenCreated(token) {
            root.embedToken = token
            var baseUrl = AirPCApiClient.getWebBaseUrl()
            var fullUrl = baseUrl + "/playtime?embed_token=" + token + "&embedded=true&platform=desktop"
            console.log("Loading playtime URL:", fullUrl)
            webView.url = fullUrl
        }

        function onEmbedTokenFailed(error) {
            root.isLoading = false
            root.hasError = true
            root.errorMessage = error
        }
    }

    // AirPC Gradient Background (visible behind WebView during loading)
    Rectangle {
        id: background
        anchors.fill: parent

        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: App.AirPCTheme.gradientStop1 }
            GradientStop { position: 0.33; color: App.AirPCTheme.gradientStop2 }
            GradientStop { position: 0.66; color: App.AirPCTheme.gradientStop3 }
            GradientStop { position: 1.0; color: App.AirPCTheme.gradientStop4 }
        }
    }

    // WebEngineView
    WebEngineView {
        id: webView
        anchors.fill: parent
        visible: root.pageLoaded && !root.hasError
        backgroundColor: "transparent"

        settings.javascriptEnabled: true
        settings.localStorageEnabled: true
        settings.pluginsEnabled: true

        onLoadingChanged: function(loadRequest) {
            switch (loadRequest.status) {
            case WebEngineView.LoadStartedStatus:
                root.isLoading = true
                break

            case WebEngineView.LoadSucceededStatus:
                root.isLoading = false
                root.pageLoaded = true
                root.hasError = false
                break

            case WebEngineView.LoadFailedStatus:
                root.isLoading = false
                root.hasError = true
                root.errorMessage = loadRequest.errorString || qsTr("Failed to load page")
                console.error("WebView load failed:", loadRequest.errorString)
                break
            }
        }

        onUrlChanged: {
            var urlStr = url.toString()
            console.log("WebView URL changed:", urlStr)

            // Detect payment completion
            if (urlStr.indexOf("/playtime/receipt") !== -1) {
                if (urlStr.indexOf("success=true") !== -1) {
                    // Payment successful - refresh profile
                    console.log("Payment successful, refreshing profile")
                    AirPCApiClient.fetchProfile()
                } else if (urlStr.indexOf("error=") !== -1) {
                    // Payment failed - extract error
                    var errorMatch = urlStr.match(/error=([^&]+)/)
                    if (errorMatch) {
                        console.warn("Payment error:", decodeURIComponent(errorMatch[1]))
                    }
                }
            }

            // Detect session expiry (redirect to login)
            if (urlStr.indexOf("/login") !== -1 || urlStr.indexOf("/auth") !== -1) {
                console.warn("Session expired, logging out")
                AirPCApiClient.logout()
            }
        }

        onNewWindowRequested: function(request) {
            // Allow Adyen 3DS popups and payment redirects (only playtime paths + payment domains)
            if (isAllowedPlaytimePath(request.requestedUrl)) {
                console.log("Allowing popup:", request.requestedUrl)
                request.openIn(webView)
            } else {
                // Block popups to non-playtime pages
                console.log("Blocking popup (not playtime path):", request.requestedUrl)
                // Don't open - just block
            }
        }

        onNavigationRequested: function(request) {
            var urlStr = request.url.toString()
            console.log("Navigation requested:", urlStr, "Type:", request.navigationType)
            
            // Only allow navigation to /playtime paths and payment domains
            if (isAllowedPlaytimePath(request.url)) {
                console.log("Allowing navigation to:", urlStr)
                request.accept()
            } else {
                // Block navigation to non-playtime pages (games, profile, etc.)
                console.log("Blocking navigation (not playtime path):", urlStr)
                request.reject()
                // Don't open externally - just block silently since it's an internal link
            }
        }

        onRenderProcessTerminated: function(terminationStatus, exitCode) {
            console.error("WebView render process terminated:", terminationStatus, exitCode)
            root.hasError = true
            root.errorMessage = qsTr("Page crashed. Please retry.")
        }
    }

    // Loading Overlay
    Rectangle {
        anchors.fill: parent
        visible: root.isLoading
        color: "transparent"

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 16

            BusyIndicator {
                Layout.alignment: Qt.AlignHCenter
                running: root.isLoading
                palette.dark: App.AirPCTheme.textOnGradient
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.embedToken.length > 0 ?
                    qsTr("Loading payment options...") :
                    qsTr("Preparing secure connection...")
                font.pixelSize: 14
                font.family: App.AirPCTheme.fontFamily
                color: App.AirPCTheme.textOnGradient
            }
        }
    }

    // Slow Loading Hint
    Timer {
        id: slowLoadTimer
        interval: 5000
        running: root.isLoading
        onTriggered: slowLoadHint.visible = true
    }

    Text {
        id: slowLoadHint
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 100
        visible: false
        text: qsTr("Taking longer than usual...")
        font.pixelSize: 12
        font.family: App.AirPCTheme.fontFamily
        color: App.AirPCTheme.textOnGradientMuted
    }

    // Error Overlay
    Rectangle {
        anchors.fill: parent
        visible: root.hasError
        color: "transparent"

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 24
            width: Math.min(400, parent.width - 64)

            // Error card
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: errorContent.implicitHeight + 56
                color: App.AirPCTheme.glassBackground
                radius: App.AirPCTheme.glassRadius
                border.color: App.AirPCTheme.glassBorder
                border.width: App.AirPCTheme.glassBorderWidth

                ColumnLayout {
                    id: errorContent
                    anchors.fill: parent
                    anchors.margins: 28
                    spacing: 16

                    Text {
                        Layout.fillWidth: true
                        text: qsTr("Unable to Load")
                        font.pixelSize: 20
                        font.weight: Font.Bold
                        font.family: App.AirPCTheme.fontFamily
                        color: App.AirPCTheme.textPrimary
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.errorMessage || qsTr("Please check your internet connection and try again.")
                        font.pixelSize: 14
                        font.family: App.AirPCTheme.fontFamily
                        color: App.AirPCTheme.textMuted
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                    }

                    App.PrimaryButton {
                        Layout.fillWidth: true
                        text: qsTr("Retry")
                        onClicked: {
                            slowLoadHint.visible = false
                            requestEmbedToken()
                        }
                    }
                }
            }
        }
    }
}
