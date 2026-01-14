import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

import AirPCApiClient 1.0
import "." as App

FocusScope {
    id: root
    objectName: "LoginView"
    
    // Design System Colors
    readonly property color primaryColor: "#8A1C5C"
    readonly property color primaryHover: Qt.lighter("#8A1C5C", 1.1)
    readonly property color primaryPressed: Qt.darker("#8A1C5C", 1.15)
    readonly property color textPrimary: "#454545"
    readonly property color textSecondary: Qt.rgba(69/255, 69/255, 69/255, 0.7)
    readonly property color textMuted: Qt.rgba(69/255, 69/255, 69/255, 0.6)
    readonly property color errorColor: "#F94141"
    readonly property color cardBackground: Qt.rgba(1, 1, 1, 0.45)
    readonly property color inputBackground: Qt.rgba(1, 1, 1, 0.05)
    readonly property color inputBackgroundHover: Qt.rgba(1, 1, 1, 0.08)
    readonly property color inputBackgroundFocus: Qt.rgba(1, 1, 1, 0.1)
    readonly property color borderDefault: Qt.rgba(69/255, 69/255, 69/255, 0.3)
    
    // Signals for integration
    signal loginRequested(string username, string password, bool rememberMe)
    signal signupRequested()
    signal forgotPasswordRequested()
    signal loginSuccessful()

    property bool loading: AirPCApiClient.isLoading
    property string errorMessage: ""

    // Background Gradient with subtle animation
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

    // Login Card with entrance animation
    Rectangle {
        id: loginCard
        width: Math.min(parent.width * 0.9, 420)
        height: Math.min(parent.height * 0.95, contentLayout.implicitHeight + 64)
        anchors.centerIn: parent
        
        // Glassmorphism effect
        color: root.cardBackground
        radius: 20
        border.color: Qt.rgba(1, 1, 1, 0.3)
        border.width: 1.5
        
        // Entrance animation
        opacity: 0
        scale: 0.95
        
        Component.onCompleted: {
            entranceAnimation.start()
        }
        
        ParallelAnimation {
            id: entranceAnimation
            NumberAnimation { target: loginCard; property: "opacity"; to: 1; duration: 400; easing.type: Easing.OutCubic }
            NumberAnimation { target: loginCard; property: "scale"; to: 1; duration: 400; easing.type: Easing.OutBack; easing.overshoot: 1.02 }
        }

        // Shadow using MultiEffect
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.18)
            shadowVerticalOffset: 20
            shadowHorizontalOffset: 0
            shadowBlur: 0.6
        }

        // Content
        ColumnLayout {
            id: contentLayout
            anchors.fill: parent
            anchors.margins: 32
            spacing: 24

            // Header Section
            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 16
                
                // Icon Wrapper with hover effect
                Rectangle {
                    id: iconWrapper
                    Layout.alignment: Qt.AlignHCenter
                    width: 72
                    height: 72
                    radius: 36
                    color: Qt.rgba(root.primaryColor.r, root.primaryColor.g, root.primaryColor.b, 0.12)
                    
                    Behavior on color { ColorAnimation { duration: 200 } }
                    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                    
                    Image {
                        id: iconImage
                        source: "qrc:/res/ic_videogame_asset_white_48px.svg"
                        width: 36
                        height: 36
                        anchors.centerIn: parent
                        visible: false
                    }
                    
                    // Color tint using MultiEffect
                    MultiEffect {
                        anchors.fill: iconImage
                        source: iconImage
                        colorization: 1.0
                        colorizationColor: root.primaryColor
                    }
                    
                    // Subtle pulse animation
                    SequentialAnimation on scale {
                        loops: Animation.Infinite
                        NumberAnimation { to: 1.03; duration: 2000; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 2000; easing.type: Easing.InOutSine }
                    }
                }

                // Title & Subtitle
                ColumnLayout {
                    spacing: 8
                    Layout.alignment: Qt.AlignHCenter
                    
                    Text {
                        text: "AirPC Desktop"
                        font.family: "Montserrat"
                        font.pixelSize: 32
                        font.weight: Font.Bold
                        font.letterSpacing: 0.5
                        color: "#FFFFFF"
                        style: Text.Outline
                        styleColor: Qt.rgba(0, 0, 0, 0.12)
                        Layout.alignment: Qt.AlignHCenter
                        
                        // Accessible
                        Accessible.role: Accessible.Heading
                        Accessible.name: text
                    }
                    
                    Text {
                        text: "Sign in to start streaming"
                        font.family: "Montserrat"
                        font.pixelSize: 14
                        font.weight: Font.Normal
                        color: Qt.rgba(1, 1, 1, 0.9)
                        Layout.alignment: Qt.AlignHCenter
                        
                        Accessible.role: Accessible.StaticText
                        Accessible.name: text
                    }
                }
            }

            // Form Section
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 20

                // Username Field
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    
                    Label {
                        text: "Username"
                        color: root.textPrimary
                        font.family: "Montserrat"
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }
                    
                    // Custom input wrapper to avoid Material floating label
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 56
                        
                        Rectangle {
                            id: usernameBg
                            anchors.fill: parent
                            color: usernameInput.activeFocus ? root.inputBackgroundFocus : 
                                   usernameInputArea.containsMouse ? root.inputBackgroundHover : root.inputBackground
                            border.color: usernameInput.activeFocus ? root.primaryColor : root.borderDefault
                            border.width: usernameInput.activeFocus ? 2 : 1
                            radius: 12
                            
                            Behavior on border.color { ColorAnimation { duration: 150 } }
                            Behavior on border.width { NumberAnimation { duration: 100 } }
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                        
                        // Static placeholder (no floating)
                        Text {
                            id: usernamePlaceholder
                            anchors.left: parent.left
                            anchors.leftMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Enter username"
                            font.family: "Montserrat"
                            font.pixelSize: 16
                            color: root.textMuted
                            visible: usernameInput.text.length === 0 && !usernameInput.activeFocus
                            
                            Behavior on opacity { NumberAnimation { duration: 100 } }
                        }
                        
                        TextInput {
                            id: usernameInput
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            verticalAlignment: TextInput.AlignVCenter
                            font.family: "Montserrat"
                            font.pixelSize: 16
                            color: root.textPrimary
                            selectByMouse: true
                            enabled: !root.loading
                            focus: true
                            clip: true
                            
                            // Accessible
                            Accessible.role: Accessible.EditableText
                            Accessible.name: "Username input"
                            Accessible.description: "Enter your username"
                            
                            Keys.onTabPressed: passwordInput.forceActiveFocus()
                            onAccepted: passwordInput.forceActiveFocus()
                        }
                        
                        MouseArea {
                            id: usernameInputArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.IBeamCursor
                            onClicked: usernameInput.forceActiveFocus()
                            acceptedButtons: Qt.NoButton
                        }
                    }
                }

                // Password Field
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    
                    Label {
                        text: "Password"
                        color: root.textPrimary
                        font.family: "Montserrat"
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }
                    
                    // Custom input wrapper to avoid Material floating label
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 56
                        
                        Rectangle {
                            id: passwordBg
                            anchors.fill: parent
                            color: passwordInput.activeFocus ? root.inputBackgroundFocus : 
                                   passwordInputArea.containsMouse ? root.inputBackgroundHover : root.inputBackground
                            border.color: passwordInput.activeFocus ? root.primaryColor : root.borderDefault
                            border.width: passwordInput.activeFocus ? 2 : 1
                            radius: 12
                            
                            Behavior on border.color { ColorAnimation { duration: 150 } }
                            Behavior on border.width { NumberAnimation { duration: 100 } }
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                        
                        // Static placeholder (no floating)
                        Text {
                            id: passwordPlaceholder
                            anchors.left: parent.left
                            anchors.leftMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Enter password"
                            font.family: "Montserrat"
                            font.pixelSize: 16
                            color: root.textMuted
                            visible: passwordInput.text.length === 0 && !passwordInput.activeFocus
                            
                            Behavior on opacity { NumberAnimation { duration: 100 } }
                        }
                        
                        TextInput {
                            id: passwordInput
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 52
                            verticalAlignment: TextInput.AlignVCenter
                            echoMode: showPasswordBtn.checked ? TextInput.Normal : TextInput.Password
                            font.family: "Montserrat"
                            font.pixelSize: 16
                            color: root.textPrimary
                            selectByMouse: true
                            enabled: !root.loading
                            clip: true
                            
                            // Accessible
                            Accessible.role: Accessible.EditableText
                            Accessible.name: "Password input"
                            Accessible.description: "Enter your password"
                            Accessible.passwordEdit: true
                            
                            Keys.onTabPressed: rememberMeCheck.forceActiveFocus()
                            onAccepted: loginBtn.clicked()
                        }
                        
                        MouseArea {
                            id: passwordInputArea
                            anchors.fill: parent
                            anchors.rightMargin: 48
                            hoverEnabled: true
                            cursorShape: Qt.IBeamCursor
                            onClicked: passwordInput.forceActiveFocus()
                            acceptedButtons: Qt.NoButton
                        }
                        
                        // Password Toggle Button with proper icons
                        AbstractButton {
                            id: showPasswordBtn
                            anchors.right: parent.right
                            anchors.rightMargin: 4
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.topMargin: 4
                            anchors.bottomMargin: 4
                            width: 44
                            checkable: true
                            enabled: !root.loading
                            
                            // Accessible
                            Accessible.role: Accessible.Button
                            Accessible.name: checked ? "Hide password" : "Show password"
                            
                            background: Rectangle {
                                radius: 8
                                color: showPasswordBtn.pressed ? Qt.rgba(0, 0, 0, 0.08) :
                                       showPasswordBtn.hovered ? Qt.rgba(0, 0, 0, 0.04) : "transparent"
                                
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }
                            
                            contentItem: Item {
                                // Eye Open Icon
                                Image {
                                    id: eyeOpenIcon
                                    anchors.centerIn: parent
                                    width: 20
                                    height: 20
                                    source: "qrc:/res/ic_visibility_white_48px.svg"
                                    visible: false
                                }
                                
                                MultiEffect {
                                    anchors.centerIn: parent
                                    width: 20
                                    height: 20
                                    source: eyeOpenIcon
                                    colorization: 1.0
                                    colorizationColor: showPasswordBtn.hovered ? root.primaryColor : root.textMuted
                                    visible: !showPasswordBtn.checked
                                    
                                    Behavior on colorizationColor { ColorAnimation { duration: 150 } }
                                }
                                
                                // Eye Closed Icon (using same icon with slash overlay)
                                Image {
                                    id: eyeClosedIcon
                                    anchors.centerIn: parent
                                    width: 20
                                    height: 20
                                    source: "qrc:/res/ic_visibility_off_white_48px.svg"
                                    visible: false
                                }
                                
                                MultiEffect {
                                    anchors.centerIn: parent
                                    width: 20
                                    height: 20
                                    source: eyeClosedIcon
                                    colorization: 1.0
                                    colorizationColor: showPasswordBtn.hovered ? root.primaryColor : root.textMuted
                                    visible: showPasswordBtn.checked
                                    
                                    Behavior on colorizationColor { ColorAnimation { duration: 150 } }
                                }
                            }
                            
                            ToolTip.visible: hovered
                            ToolTip.text: checked ? "Hide password" : "Show password"
                            ToolTip.delay: 500
                        }
                    }
                }
                
                // Options Row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    
                    // Custom Checkbox
                    CheckBox {
                        id: rememberMeCheck
                        text: "Remember me"
                        font.family: "Montserrat"
                        font.pixelSize: 12
                        checked: true
                        enabled: !root.loading
                        
                        // Accessible
                        Accessible.role: Accessible.CheckBox
                        Accessible.name: "Remember me"
                        Accessible.checked: checked
                        
                        indicator: Rectangle {
                            implicitWidth: 18
                            implicitHeight: 18
                            x: rememberMeCheck.leftPadding
                            y: parent.height / 2 - height / 2
                            radius: 9
                            border.color: rememberMeCheck.checked ? root.primaryColor : 
                                         rememberMeCheck.hovered ? root.primaryColor : root.textMuted
                            border.width: 2
                            color: rememberMeCheck.checked ? root.primaryColor : "transparent"
                            
                            Behavior on border.color { ColorAnimation { duration: 150 } }
                            Behavior on color { ColorAnimation { duration: 150 } }
                            
                            // Checkmark
                            Item {
                                anchors.centerIn: parent
                                width: 10
                                height: 10
                                opacity: rememberMeCheck.checked ? 1 : 0
                                scale: rememberMeCheck.checked ? 1 : 0.5
                                
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                                
                                // Checkmark shape using Canvas
                                Canvas {
                                    anchors.fill: parent
                                    onPaint: {
                                        var ctx = getContext("2d")
                                        ctx.clearRect(0, 0, width, height)
                                        ctx.strokeStyle = "white"
                                        ctx.lineWidth = 2
                                        ctx.lineCap = "round"
                                        ctx.lineJoin = "round"
                                        ctx.beginPath()
                                        ctx.moveTo(2, 5)
                                        ctx.lineTo(4, 8)
                                        ctx.lineTo(8, 2)
                                        ctx.stroke()
                                    }
                                }
                            }
                        }
                        
                        contentItem: Text {
                            text: rememberMeCheck.text
                            font: rememberMeCheck.font
                            color: root.textPrimary
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: rememberMeCheck.indicator.width + rememberMeCheck.spacing + 4
                        }
                        
                        Keys.onTabPressed: forgotPasswordLink.forceActiveFocus()
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    // Forgot Password Link
                    AbstractButton {
                        id: forgotPasswordLink
                        
                        // Accessible
                        Accessible.role: Accessible.Link
                        Accessible.name: "Forgot password"
                        
                        contentItem: Text {
                            id: forgotPassText
                            text: "Forgot password?"
                            color: forgotPasswordLink.pressed ? root.primaryPressed : 
                                   forgotPasswordLink.hovered ? root.primaryHover : root.primaryColor
                            font.family: "Montserrat"
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                        
                        background: Rectangle {
                            color: "transparent"
                            
                            // Underline on hover
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 1
                                color: forgotPassText.color
                                opacity: forgotPasswordLink.hovered ? 1 : 0
                                
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }
                        }
                        
                        onClicked: root.forgotPasswordRequested()
                        
                        HoverHandler {
                            cursorShape: Qt.PointingHandCursor
                        }
                        
                        Keys.onTabPressed: loginBtn.forceActiveFocus()
                    }
                }
            }

            // Error Message with animation
            Rectangle {
                id: errorContainer
                Layout.fillWidth: true
                Layout.preferredHeight: errorVisible ? 48 : 0
                clip: true
                
                property bool errorVisible: root.errorMessage !== ""
                
                Behavior on Layout.preferredHeight { 
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic } 
                }
                
                color: Qt.rgba(root.errorColor.r, root.errorColor.g, root.errorColor.b, 0.12)
                border.color: Qt.rgba(root.errorColor.r, root.errorColor.g, root.errorColor.b, 0.25)
                border.width: 1
                radius: 12
                
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 10
                    opacity: errorContainer.errorVisible ? 1 : 0
                    
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                    
                    Image {
                        id: errorIcon
                        source: "qrc:/res/baseline-error_outline-24px.svg"
                        Layout.preferredWidth: 18
                        Layout.preferredHeight: 18
                        visible: false
                    }
                    
                    MultiEffect {
                        Layout.preferredWidth: 18
                        Layout.preferredHeight: 18
                        source: errorIcon
                        colorization: 1.0
                        colorizationColor: root.errorColor
                    }
                    
                    Text {
                        text: root.errorMessage
                        color: root.errorColor
                        font.family: "Montserrat"
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        
                        Accessible.role: Accessible.AlertMessage
                        Accessible.name: "Error: " + text
                    }
                }
                
                // Shake animation on error
                SequentialAnimation {
                    id: shakeAnimation
                    PropertyAnimation { target: errorContainer; property: "x"; to: -8; duration: 50 }
                    PropertyAnimation { target: errorContainer; property: "x"; to: 8; duration: 50 }
                    PropertyAnimation { target: errorContainer; property: "x"; to: -6; duration: 50 }
                    PropertyAnimation { target: errorContainer; property: "x"; to: 6; duration: 50 }
                    PropertyAnimation { target: errorContainer; property: "x"; to: 0; duration: 50 }
                }
            }

            // Submit Button
            Button {
                id: loginBtn
                Layout.fillWidth: true
                Layout.preferredHeight: 54
                Layout.topMargin: 8
                enabled: !root.loading
                
                // Accessible
                Accessible.role: Accessible.Button
                Accessible.name: root.loading ? "Logging in" : "Sign In"
                
                contentItem: RowLayout {
                    spacing: 10
                    Item { Layout.fillWidth: true }
                    
                    // Loading Spinner
                    Item {
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 22
                        visible: root.loading
                        
                        Rectangle {
                            id: spinnerRing
                            anchors.fill: parent
                            color: "transparent"
                            radius: width / 2
                            border.width: 2.5
                            border.color: Qt.rgba(1, 1, 1, 0.3)
                        }
                        
                        // Spinner arc
                        Canvas {
                            id: spinnerArc
                            anchors.fill: parent
                            
                            property real rotation: 0
                            
                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.clearRect(0, 0, width, height)
                                ctx.strokeStyle = "white"
                                ctx.lineWidth = 2.5
                                ctx.lineCap = "round"
                                ctx.beginPath()
                                var startAngle = rotation * Math.PI / 180
                                var endAngle = startAngle + Math.PI * 0.75
                                ctx.arc(width/2, height/2, width/2 - 2, startAngle, endAngle)
                                ctx.stroke()
                            }
                            
                            NumberAnimation on rotation {
                                from: 0
                                to: 360
                                duration: 1000
                                loops: Animation.Infinite
                                running: root.loading
                            }
                            
                            onRotationChanged: requestPaint()
                        }
                    }
                    
                    Text {
                        text: root.loading ? "Logging in..." : "Sign In"
                        font.family: "Montserrat"
                        font.pixelSize: 16
                        font.weight: Font.SemiBold
                        font.letterSpacing: 0.3
                        color: "#FFFFFF"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    Item { Layout.fillWidth: true }
                }

                background: Rectangle {
                    id: loginBtnBg
                    color: {
                        if (!loginBtn.enabled) return Qt.rgba(root.primaryColor.r, root.primaryColor.g, root.primaryColor.b, 0.5)
                        if (loginBtn.pressed) return root.primaryPressed
                        if (loginBtn.hovered) return root.primaryHover
                        return root.primaryColor
                    }
                    radius: 27
                    
                    Behavior on color { ColorAnimation { duration: 150 } }
                    
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: !loginBtn.pressed
                        shadowColor: Qt.rgba(root.primaryColor.r, root.primaryColor.g, root.primaryColor.b, 0.35)
                        shadowVerticalOffset: loginBtn.hovered ? 6 : 4
                        shadowHorizontalOffset: 0
                        shadowBlur: loginBtn.hovered ? 0.4 : 0.3
                        
                        Behavior on shadowVerticalOffset { NumberAnimation { duration: 150 } }
                        Behavior on shadowBlur { NumberAnimation { duration: 150 } }
                    }
                    
                    // Press feedback
                    scale: loginBtn.pressed ? 0.98 : 1
                    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                }
                
                HoverHandler {
                    cursorShape: loginBtn.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                }
                
                Keys.onTabPressed: signupLink.forceActiveFocus()
                
                onClicked: {
                    if (usernameInput.text.trim() === "" || passwordInput.text === "") {
                        root.errorMessage = "Please enter username and password"
                        shakeAnimation.start()
                    } else {
                        root.errorMessage = ""
                        // Call the real API
                        AirPCApiClient.login(usernameInput.text.trim(), passwordInput.text, rememberMeCheck.checked)
                    }
                }
            }
            
            // Sign Up Section
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 12
                spacing: 4
                
                Text {
                    text: "Don't have an account?"
                    color: root.textSecondary
                    font.family: "Montserrat"
                    font.pixelSize: 13
                }
                
                AbstractButton {
                    id: signupLink
                    
                    // Accessible
                    Accessible.role: Accessible.Link
                    Accessible.name: "Sign up"
                    
                    contentItem: Text {
                        id: signupText
                        text: "Sign up"
                        color: signupLink.pressed ? root.primaryPressed : 
                               signupLink.hovered ? root.primaryHover : root.primaryColor
                        font.family: "Montserrat"
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    
                    background: Rectangle {
                        color: "transparent"
                        
                        // Underline on hover
                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 1
                            color: signupText.color
                            opacity: signupLink.hovered ? 1 : 0
                            
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                        }
                    }
                    
                    onClicked: root.signupRequested()
                    
                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                    }
                    
                    Keys.onTabPressed: usernameInput.forceActiveFocus()
                }
            }
        }
    }

    // Keyboard shortcuts
    Shortcut {
        sequence: "Return"
        enabled: !root.loading && (usernameInput.activeFocus || passwordInput.activeFocus)
        onActivated: loginBtn.clicked()
    }

    // Connect to API signals
    Connections {
        target: AirPCApiClient
        
        function onLoginSuccess() {
            console.log("Login successful, navigating to game library...")
            root.loginRequested(usernameInput.text, passwordInput.text, rememberMeCheck.checked)
            root.loginSuccessful()
            // Navigate to game library via Router
            App.Router.onLoginSuccess()
        }
        
        function onLoginFailed(error) {
            console.log("Login failed:", error)
            root.errorMessage = error
            shakeAnimation.start()
            // Return focus to password field on error
            passwordInput.forceActiveFocus()
            passwordInput.selectAll()
        }
        
        function onLoadingChanged() {
            // Loading state is bound directly via property
        }
    }

    // Check if already logged in on component load
    Component.onCompleted: {
        if (AirPCApiClient.isLoggedIn) {
            console.log("Already logged in, navigating to game library...")
            App.Router.onLoginSuccess()
        } else {
            // Auto-focus username field
            usernameInput.forceActiveFocus()
        }
    }
}
