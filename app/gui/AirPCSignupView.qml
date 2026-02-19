import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

import AirPCApiClient 1.0
import "." as App

FocusScope {
    id: root
    objectName: "SignupView"

    // Design System Colors (matching AirPCLoginView exactly)
    readonly property color primaryColor: "#8A1C5C"
    readonly property color primaryHover: Qt.lighter("#8A1C5C", 1.1)
    readonly property color primaryPressed: Qt.darker("#8A1C5C", 1.15)
    readonly property color textPrimary: "#454545"
    readonly property color textSecondary: Qt.rgba(69/255, 69/255, 69/255, 0.7)
    readonly property color textMuted: Qt.rgba(69/255, 69/255, 69/255, 0.6)
    readonly property color errorColor: "#F94141"
    readonly property color successColor: "#22C55E"
    readonly property color cardBackground: Qt.rgba(1, 1, 1, 0.45)
    readonly property color inputBackground: Qt.rgba(1, 1, 1, 0.05)
    readonly property color inputBackgroundHover: Qt.rgba(1, 1, 1, 0.08)
    readonly property color inputBackgroundFocus: Qt.rgba(1, 1, 1, 0.1)
    readonly property color borderDefault: Qt.rgba(69/255, 69/255, 69/255, 0.3)

    // Local state — do NOT use AirPCApiClient.isLoading
    property bool signupLoading: false
    property bool resendLoading: false
    property string errorMessage: ""
    property string resendErrorMessage: ""
    property bool resendSuccess: false

    // State machine: "form" | "success"
    property string viewState: "form"
    property string registeredEmail: ""

    // Per-field validation errors
    property string usernameError: ""
    property string emailError: ""
    property string passwordError: ""
    property string confirmPasswordError: ""

    // --- Helpers ---
    function validateEmail(addr) {
        // mirrors /^[^\s@]+@[^\s@]+\.[^\s@]+$/
        return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(addr)
    }

    function validateForm() {
        var ok = true

        // Username
        if (usernameInput.text.trim().length < 3) {
            root.usernameError = "Username must be at least 3 characters"
            ok = false
        } else if (usernameInput.text.trim().length > 50) {
            root.usernameError = "Username must be at most 50 characters"
            ok = false
        } else {
            root.usernameError = ""
        }

        // Email
        if (!root.validateEmail(emailInput.text.trim())) {
            root.emailError = "Please enter a valid email address"
            ok = false
        } else {
            root.emailError = ""
        }

        // Password
        if (passwordInput.text.length < 8) {
            root.passwordError = "Password must be at least 8 characters"
            ok = false
        } else {
            root.passwordError = ""
        }

        // Confirm password
        if (confirmPasswordInput.text !== passwordInput.text) {
            root.confirmPasswordError = "Passwords do not match"
            ok = false
        } else {
            root.confirmPasswordError = ""
        }

        return ok
    }

    // Background Gradient
    Rectangle {
        id: background
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0;  color: "#DED1C6" }
            GradientStop { position: 0.33; color: "#A77693" }
            GradientStop { position: 0.66; color: "#174871" }
            GradientStop { position: 1.0;  color: "#0F2D4D" }
        }
    }

    // Signup Card — scrollable so it works on small desktop windows
    Rectangle {
        id: signupCard
        width: Math.min(parent.width * 0.9, 420)
        height: Math.min(parent.height * 0.98, contentLayout.implicitHeight + 64)
        anchors.centerIn: parent
        clip: true

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
            NumberAnimation { target: signupCard; property: "opacity"; to: 1; duration: 400; easing.type: Easing.OutCubic }
            NumberAnimation { target: signupCard; property: "scale"; to: 1; duration: 400; easing.type: Easing.OutBack; easing.overshoot: 1.02 }
        }

        layer.enabled: false

        // Flickable wrapper so content scrolls on small windows
        Flickable {
            id: flickable
            anchors.fill: parent
            contentWidth: width
            contentHeight: contentLayout.implicitHeight + 64
            clip: true
            flickableDirection: Flickable.VerticalFlick

            ScrollBar.vertical: ScrollBar {
                policy: flickable.contentHeight > flickable.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
            }

            // ── FORM STATE ──────────────────────────────────────────────
            ColumnLayout {
                id: contentLayout
                width: flickable.width
                anchors.top: parent.top
                anchors.topMargin: 32
                anchors.left: parent.left
                anchors.leftMargin: 32
                anchors.right: parent.right
                anchors.rightMargin: 32
                spacing: 20

                visible: root.viewState === "form"

                // Header
                ColumnLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 16

                    // Icon wrapper
                    Rectangle {
                        id: iconWrapper
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: 72
                        implicitHeight: 72
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

                        MultiEffect {
                            anchors.fill: iconImage
                            source: iconImage
                            colorization: 1.0
                            colorizationColor: root.primaryColor
                        }

                        SequentialAnimation on scale {
                            loops: Animation.Infinite
                            NumberAnimation { to: 1.03; duration: 2000; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.0;  duration: 2000; easing.type: Easing.InOutSine }
                        }
                    }

                    // Title & Subtitle
                    ColumnLayout {
                        spacing: 8
                        Layout.alignment: Qt.AlignHCenter

                        Text {
                            text: "Create Account"
                            font.family: "Montserrat"
                            font.pixelSize: 28
                            font.weight: Font.Bold
                            font.letterSpacing: 0.5
                            color: "#FFFFFF"
                            style: Text.Outline
                            styleColor: Qt.rgba(0, 0, 0, 0.12)
                            Layout.alignment: Qt.AlignHCenter

                            Accessible.role: Accessible.Heading
                            Accessible.name: text
                        }

                        Text {
                            text: "Sign up to start streaming games"
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

                // ── FORM FIELDS ─────────────────────────────────────────

                // 1. Username
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Label {
                        text: "Username"
                        color: root.textPrimary
                        font.family: "Montserrat"
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 56

                        Rectangle {
                            id: usernameBg
                            anchors.fill: parent
                            color: usernameInput.activeFocus ? root.inputBackgroundFocus :
                                   usernameInputArea.containsMouse ? root.inputBackgroundHover : root.inputBackground
                            border.color: root.usernameError !== "" ? root.errorColor :
                                          usernameInput.activeFocus ? root.primaryColor : root.borderDefault
                            border.width: usernameInput.activeFocus ? 2 : 1
                            radius: 12

                            Behavior on border.color { ColorAnimation { duration: 150 } }
                            Behavior on border.width { NumberAnimation { duration: 100 } }
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Choose a username"
                            font.family: "Montserrat"
                            font.pixelSize: 16
                            color: root.textMuted
                            visible: usernameInput.text.length === 0 && !usernameInput.activeFocus
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
                            enabled: !root.signupLoading
                            focus: true
                            clip: true

                            Accessible.role: Accessible.EditableText
                            Accessible.name: "Username input"
                            Accessible.description: "Choose a username"

                            onTextChanged: root.usernameError = ""
                            Keys.onTabPressed: emailInput.forceActiveFocus()
                            onAccepted: emailInput.forceActiveFocus()
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

                    // Inline validation error
                    Text {
                        visible: root.usernameError !== ""
                        text: root.usernameError
                        color: root.errorColor
                        font.family: "Montserrat"
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        leftPadding: 4

                        Accessible.role: Accessible.AlertMessage
                        Accessible.name: text
                    }
                }

                // 2. Email
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Label {
                        text: "Email"
                        color: root.textPrimary
                        font.family: "Montserrat"
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 56

                        Rectangle {
                            id: emailBg
                            anchors.fill: parent
                            color: emailInput.activeFocus ? root.inputBackgroundFocus :
                                   emailInputArea.containsMouse ? root.inputBackgroundHover : root.inputBackground
                            border.color: root.emailError !== "" ? root.errorColor :
                                          emailInput.activeFocus ? root.primaryColor : root.borderDefault
                            border.width: emailInput.activeFocus ? 2 : 1
                            radius: 12

                            Behavior on border.color { ColorAnimation { duration: 150 } }
                            Behavior on border.width { NumberAnimation { duration: 100 } }
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Enter your email"
                            font.family: "Montserrat"
                            font.pixelSize: 16
                            color: root.textMuted
                            visible: emailInput.text.length === 0 && !emailInput.activeFocus
                        }

                        TextInput {
                            id: emailInput
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            verticalAlignment: TextInput.AlignVCenter
                            font.family: "Montserrat"
                            font.pixelSize: 16
                            color: root.textPrimary
                            selectByMouse: true
                            enabled: !root.signupLoading
                            inputMethodHints: Qt.ImhEmailCharactersOnly
                            clip: true

                            Accessible.role: Accessible.EditableText
                            Accessible.name: "Email input"
                            Accessible.description: "Enter your email address"

                            onTextChanged: root.emailError = ""
                            Keys.onTabPressed: passwordInput.forceActiveFocus()
                            onAccepted: passwordInput.forceActiveFocus()
                        }

                        MouseArea {
                            id: emailInputArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.IBeamCursor
                            onClicked: emailInput.forceActiveFocus()
                            acceptedButtons: Qt.NoButton
                        }
                    }

                    Text {
                        visible: root.emailError !== ""
                        text: root.emailError
                        color: root.errorColor
                        font.family: "Montserrat"
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        leftPadding: 4

                        Accessible.role: Accessible.AlertMessage
                        Accessible.name: text
                    }
                }

                // 3. Password
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Label {
                        text: "Password"
                        color: root.textPrimary
                        font.family: "Montserrat"
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 56

                        Rectangle {
                            id: passwordBg
                            anchors.fill: parent
                            color: passwordInput.activeFocus ? root.inputBackgroundFocus :
                                   passwordInputArea.containsMouse ? root.inputBackgroundHover : root.inputBackground
                            border.color: root.passwordError !== "" ? root.errorColor :
                                          passwordInput.activeFocus ? root.primaryColor : root.borderDefault
                            border.width: passwordInput.activeFocus ? 2 : 1
                            radius: 12

                            Behavior on border.color { ColorAnimation { duration: 150 } }
                            Behavior on border.width { NumberAnimation { duration: 100 } }
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Create a password (min 8 characters)"
                            font.family: "Montserrat"
                            font.pixelSize: 14
                            color: root.textMuted
                            visible: passwordInput.text.length === 0 && !passwordInput.activeFocus
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
                            enabled: !root.signupLoading
                            clip: true

                            Accessible.role: Accessible.EditableText
                            Accessible.name: "Password input"
                            Accessible.description: "Create a password (min 8 characters)"
                            Accessible.passwordEdit: true

                            onTextChanged: root.passwordError = ""
                            Keys.onTabPressed: confirmPasswordInput.forceActiveFocus()
                            onAccepted: confirmPasswordInput.forceActiveFocus()
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

                        // Password visibility toggle
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
                            enabled: !root.signupLoading

                            Accessible.role: Accessible.Button
                            Accessible.name: checked ? "Hide password" : "Show password"

                            background: Rectangle {
                                radius: 8
                                color: showPasswordBtn.pressed ? Qt.rgba(0, 0, 0, 0.08) :
                                       showPasswordBtn.hovered ? Qt.rgba(0, 0, 0, 0.04) : "transparent"
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }

                            contentItem: Item {
                                Image {
                                    id: eyeOpenIcon
                                    anchors.centerIn: parent
                                    width: 20; height: 20
                                    source: "qrc:/res/ic_visibility_white_48px.svg"
                                    visible: false
                                }
                                MultiEffect {
                                    anchors.centerIn: parent
                                    width: 20; height: 20
                                    source: eyeOpenIcon
                                    colorization: 1.0
                                    colorizationColor: showPasswordBtn.hovered ? root.primaryColor : root.textMuted
                                    visible: !showPasswordBtn.checked
                                    Behavior on colorizationColor { ColorAnimation { duration: 150 } }
                                }
                                Image {
                                    id: eyeClosedIcon
                                    anchors.centerIn: parent
                                    width: 20; height: 20
                                    source: "qrc:/res/ic_visibility_off_white_48px.svg"
                                    visible: false
                                }
                                MultiEffect {
                                    anchors.centerIn: parent
                                    width: 20; height: 20
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

                    Text {
                        visible: root.passwordError !== ""
                        text: root.passwordError
                        color: root.errorColor
                        font.family: "Montserrat"
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        leftPadding: 4

                        Accessible.role: Accessible.AlertMessage
                        Accessible.name: text
                    }
                }

                // 4. Confirm Password
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Label {
                        text: "Confirm Password"
                        color: root.textPrimary
                        font.family: "Montserrat"
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 56

                        Rectangle {
                            id: confirmPasswordBg
                            anchors.fill: parent
                            color: confirmPasswordInput.activeFocus ? root.inputBackgroundFocus :
                                   confirmPasswordInputArea.containsMouse ? root.inputBackgroundHover : root.inputBackground
                            border.color: root.confirmPasswordError !== "" ? root.errorColor :
                                          confirmPasswordInput.activeFocus ? root.primaryColor : root.borderDefault
                            border.width: confirmPasswordInput.activeFocus ? 2 : 1
                            radius: 12

                            Behavior on border.color { ColorAnimation { duration: 150 } }
                            Behavior on border.width { NumberAnimation { duration: 100 } }
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Confirm your password"
                            font.family: "Montserrat"
                            font.pixelSize: 16
                            color: root.textMuted
                            visible: confirmPasswordInput.text.length === 0 && !confirmPasswordInput.activeFocus
                        }

                        TextInput {
                            id: confirmPasswordInput
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 52
                            verticalAlignment: TextInput.AlignVCenter
                            echoMode: showConfirmPasswordBtn.checked ? TextInput.Normal : TextInput.Password
                            font.family: "Montserrat"
                            font.pixelSize: 16
                            color: root.textPrimary
                            selectByMouse: true
                            enabled: !root.signupLoading
                            clip: true

                            Accessible.role: Accessible.EditableText
                            Accessible.name: "Confirm password input"
                            Accessible.description: "Re-enter your password to confirm"
                            Accessible.passwordEdit: true

                            onTextChanged: root.confirmPasswordError = ""
                            Keys.onTabPressed: signupBtn.forceActiveFocus()
                            onAccepted: signupBtn.clicked()
                        }

                        MouseArea {
                            id: confirmPasswordInputArea
                            anchors.fill: parent
                            anchors.rightMargin: 48
                            hoverEnabled: true
                            cursorShape: Qt.IBeamCursor
                            onClicked: confirmPasswordInput.forceActiveFocus()
                            acceptedButtons: Qt.NoButton
                        }

                        // Confirm password visibility toggle
                        AbstractButton {
                            id: showConfirmPasswordBtn
                            anchors.right: parent.right
                            anchors.rightMargin: 4
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.topMargin: 4
                            anchors.bottomMargin: 4
                            width: 44
                            checkable: true
                            enabled: !root.signupLoading

                            Accessible.role: Accessible.Button
                            Accessible.name: checked ? "Hide confirm password" : "Show confirm password"

                            background: Rectangle {
                                radius: 8
                                color: showConfirmPasswordBtn.pressed ? Qt.rgba(0, 0, 0, 0.08) :
                                       showConfirmPasswordBtn.hovered ? Qt.rgba(0, 0, 0, 0.04) : "transparent"
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }

                            contentItem: Item {
                                Image {
                                    id: confirmEyeOpenIcon
                                    anchors.centerIn: parent
                                    width: 20; height: 20
                                    source: "qrc:/res/ic_visibility_white_48px.svg"
                                    visible: false
                                }
                                MultiEffect {
                                    anchors.centerIn: parent
                                    width: 20; height: 20
                                    source: confirmEyeOpenIcon
                                    colorization: 1.0
                                    colorizationColor: showConfirmPasswordBtn.hovered ? root.primaryColor : root.textMuted
                                    visible: !showConfirmPasswordBtn.checked
                                    Behavior on colorizationColor { ColorAnimation { duration: 150 } }
                                }
                                Image {
                                    id: confirmEyeClosedIcon
                                    anchors.centerIn: parent
                                    width: 20; height: 20
                                    source: "qrc:/res/ic_visibility_off_white_48px.svg"
                                    visible: false
                                }
                                MultiEffect {
                                    anchors.centerIn: parent
                                    width: 20; height: 20
                                    source: confirmEyeClosedIcon
                                    colorization: 1.0
                                    colorizationColor: showConfirmPasswordBtn.hovered ? root.primaryColor : root.textMuted
                                    visible: showConfirmPasswordBtn.checked
                                    Behavior on colorizationColor { ColorAnimation { duration: 150 } }
                                }
                            }

                            ToolTip.visible: hovered
                            ToolTip.text: checked ? "Hide password" : "Show password"
                            ToolTip.delay: 500
                        }
                    }

                    Text {
                        visible: root.confirmPasswordError !== ""
                        text: root.confirmPasswordError
                        color: root.errorColor
                        font.family: "Montserrat"
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        leftPadding: 4

                        Accessible.role: Accessible.AlertMessage
                        Accessible.name: text
                    }
                }

                // ── Global error container (same shake animation as LoginView) ──
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

                    SequentialAnimation {
                        id: shakeAnimation
                        PropertyAnimation { target: errorContainer; property: "x"; to: -8; duration: 50 }
                        PropertyAnimation { target: errorContainer; property: "x"; to:  8; duration: 50 }
                        PropertyAnimation { target: errorContainer; property: "x"; to: -6; duration: 50 }
                        PropertyAnimation { target: errorContainer; property: "x"; to:  6; duration: 50 }
                        PropertyAnimation { target: errorContainer; property: "x"; to:  0; duration: 50 }
                    }
                }

                // ── Submit Button ──────────────────────────────────────
                Button {
                    id: signupBtn
                    Layout.fillWidth: true
                    Layout.preferredHeight: 54
                    Layout.topMargin: 4
                    enabled: !root.signupLoading

                    Accessible.role: Accessible.Button
                    Accessible.name: root.signupLoading ? "Creating account" : "Create Account"

                    contentItem: RowLayout {
                        spacing: 10
                        Item { Layout.fillWidth: true }

                        // Loading spinner
                        Item {
                            Layout.preferredWidth: 22
                            Layout.preferredHeight: 22
                            visible: root.signupLoading

                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                radius: width / 2
                                border.width: 2.5
                                border.color: Qt.rgba(1, 1, 1, 0.3)
                            }

                            Canvas {
                                id: signupSpinnerArc
                                anchors.fill: parent
                                property real spinAngle

                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.clearRect(0, 0, width, height)
                                    ctx.strokeStyle = "white"
                                    ctx.lineWidth = 2.5
                                    ctx.lineCap = "round"
                                    ctx.beginPath()
                                    var startAngle = spinAngle * Math.PI / 180
                                    var endAngle = startAngle + Math.PI * 0.75
                                    ctx.arc(width/2, height/2, width/2 - 2, startAngle, endAngle)
                                    ctx.stroke()
                                }

                                NumberAnimation on spinAngle {
                                    from: 0; to: 360
                                    duration: 1000
                                    loops: Animation.Infinite
                                    running: root.signupLoading
                                }

                                onSpinAngleChanged: requestPaint()
                            }
                        }

                        Text {
                            text: root.signupLoading ? "Creating account..." : "Create Account"
                            font.family: "Montserrat"
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                            font.letterSpacing: 0.3
                            color: "#FFFFFF"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        Item { Layout.fillWidth: true }
                    }

                    background: Rectangle {
                        color: {
                            if (!signupBtn.enabled) return Qt.rgba(root.primaryColor.r, root.primaryColor.g, root.primaryColor.b, 0.5)
                            if (signupBtn.pressed) return root.primaryPressed
                            if (signupBtn.hovered) return root.primaryHover
                            return root.primaryColor
                        }
                        radius: 27
                        Behavior on color { ColorAnimation { duration: 150 } }
                        layer.enabled: false
                        scale: signupBtn.pressed ? 0.98 : 1
                        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                    }

                    HoverHandler {
                        cursorShape: signupBtn.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    }

                    Keys.onTabPressed: signInLink.forceActiveFocus()

                    onClicked: {
                        root.errorMessage = ""
                        if (!root.validateForm()) {
                            // show shake only if there's also a global error to report
                            return
                        }
                        root.signupLoading = true
                        AirPCApiClient.signup(
                            usernameInput.text.trim(),
                            emailInput.text.trim(),
                            passwordInput.text,
                            confirmPasswordInput.text
                        )
                    }
                }

                // ── Sign In Link ───────────────────────────────────────
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 8
                    Layout.bottomMargin: 16
                    spacing: 4

                    Text {
                        text: "Already have an account?"
                        color: root.textSecondary
                        font.family: "Montserrat"
                        font.pixelSize: 13
                    }

                    AbstractButton {
                        id: signInLink

                        Accessible.role: Accessible.Link
                        Accessible.name: "Sign in"

                        contentItem: Text {
                            id: signInText
                            text: "Sign in"
                            color: signInLink.pressed ? root.primaryPressed :
                                   signInLink.hovered ? root.primaryHover : root.primaryColor
                            font.family: "Montserrat"
                            font.pixelSize: 13
                            font.weight: Font.Bold
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        background: Rectangle {
                            color: "transparent"
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 1
                                color: signInText.color
                                opacity: signInLink.hovered ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }
                        }

                        onClicked: App.Router.back()

                        HoverHandler { cursorShape: Qt.PointingHandCursor }

                        Keys.onTabPressed: usernameInput.forceActiveFocus()
                    }
                }
            } // end form ColumnLayout

            // ── SUCCESS STATE ────────────────────────────────────────────
            ColumnLayout {
                id: successLayout
                width: flickable.width
                anchors.top: parent.top
                anchors.topMargin: 40
                anchors.left: parent.left
                anchors.leftMargin: 32
                anchors.right: parent.right
                anchors.rightMargin: 32
                spacing: 20

                visible: root.viewState === "success"

                // Mail / check icon area
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 80
                    implicitHeight: 80
                    radius: 40
                    color: Qt.rgba(root.successColor.r, root.successColor.g, root.successColor.b, 0.12)

                    // Checkmark drawn on canvas
                    Canvas {
                        anchors.centerIn: parent
                        width: 40
                        height: 40
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            ctx.strokeStyle = root.successColor.toString()
                            ctx.lineWidth = 3
                            ctx.lineCap = "round"
                            ctx.lineJoin = "round"
                            // Mail envelope outline
                            ctx.beginPath()
                            ctx.rect(4, 8, 32, 24)
                            ctx.stroke()
                            // Mail flap
                            ctx.beginPath()
                            ctx.moveTo(4, 8)
                            ctx.lineTo(20, 22)
                            ctx.lineTo(36, 8)
                            ctx.stroke()
                            // Checkmark overlay (bottom right)
                            ctx.strokeStyle = root.successColor.toString()
                            ctx.lineWidth = 2.5
                            ctx.beginPath()
                            ctx.moveTo(24, 28)
                            ctx.lineTo(28, 33)
                            ctx.lineTo(36, 22)
                            ctx.stroke()
                        }
                    }

                    SequentialAnimation on scale {
                        loops: Animation.Infinite
                        NumberAnimation { to: 1.04; duration: 2000; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0;  duration: 2000; easing.type: Easing.InOutSine }
                    }
                }

                // Title
                Text {
                    text: "Check Your Email"
                    font.family: "Montserrat"
                    font.pixelSize: 26
                    font.weight: Font.Bold
                    color: "#FFFFFF"
                    style: Text.Outline
                    styleColor: Qt.rgba(0, 0, 0, 0.12)
                    Layout.alignment: Qt.AlignHCenter

                    Accessible.role: Accessible.Heading
                    Accessible.name: text
                }

                // Subtitle
                Text {
                    text: "We've sent a verification link to"
                    font.family: "Montserrat"
                    font.pixelSize: 14
                    color: Qt.rgba(1, 1, 1, 0.9)
                    Layout.alignment: Qt.AlignHCenter
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true

                    Accessible.role: Accessible.StaticText
                    Accessible.name: text
                }

                // Highlighted email
                Text {
                    text: root.registeredEmail
                    font.family: "Montserrat"
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                    color: root.primaryColor
                    Layout.alignment: Qt.AlignHCenter
                    elide: Text.ElideMiddle
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter

                    Accessible.role: Accessible.StaticText
                    Accessible.name: "Email: " + text
                }

                // Instruction body
                Text {
                    text: "Click the link in the email to verify your account. Once verified, you can log in to start streaming."
                    font.family: "Montserrat"
                    font.pixelSize: 13
                    color: Qt.rgba(1, 1, 1, 0.8)
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true

                    Accessible.role: Accessible.StaticText
                    Accessible.name: text
                }

                // ── Resend success badge ──────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.resendSuccess ? 44 : 0
                    clip: true
                    color: Qt.rgba(root.successColor.r, root.successColor.g, root.successColor.b, 0.12)
                    border.color: Qt.rgba(root.successColor.r, root.successColor.g, root.successColor.b, 0.3)
                    border.width: 1
                    radius: 12

                    Behavior on Layout.preferredHeight {
                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                    }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8
                        opacity: root.resendSuccess ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 150 } }

                        Canvas {
                            implicitWidth: 18
                            implicitHeight: 18
                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.clearRect(0, 0, width, height)
                                ctx.strokeStyle = root.successColor.toString()
                                ctx.lineWidth = 2
                                ctx.lineCap = "round"
                                ctx.lineJoin = "round"
                                ctx.beginPath()
                                ctx.moveTo(3, 9)
                                ctx.lineTo(7, 13)
                                ctx.lineTo(15, 5)
                                ctx.stroke()
                            }
                        }

                        Text {
                            text: "Verification email sent!"
                            color: root.successColor
                            font.family: "Montserrat"
                            font.pixelSize: 13
                            font.weight: Font.Medium

                            Accessible.role: Accessible.AlertMessage
                            Accessible.name: text
                        }
                    }
                }

                // ── Resend error ──────────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.resendErrorMessage !== "" ? 44 : 0
                    clip: true
                    color: Qt.rgba(root.errorColor.r, root.errorColor.g, root.errorColor.b, 0.12)
                    border.color: Qt.rgba(root.errorColor.r, root.errorColor.g, root.errorColor.b, 0.25)
                    border.width: 1
                    radius: 12

                    Behavior on Layout.preferredHeight {
                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 10
                        opacity: root.resendErrorMessage !== "" ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 150 } }

                        Image {
                            id: resendErrorIcon
                            source: "qrc:/res/baseline-error_outline-24px.svg"
                            Layout.preferredWidth: 18
                            Layout.preferredHeight: 18
                            visible: false
                        }
                        MultiEffect {
                            Layout.preferredWidth: 18
                            Layout.preferredHeight: 18
                            source: resendErrorIcon
                            colorization: 1.0
                            colorizationColor: root.errorColor
                        }

                        Text {
                            text: root.resendErrorMessage
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
                }

                // ── Resend Email button (secondary/outline style) ──────
                Button {
                    id: resendBtn
                    Layout.fillWidth: true
                    Layout.preferredHeight: 54
                    enabled: !root.resendLoading

                    Accessible.role: Accessible.Button
                    Accessible.name: root.resendLoading ? "Sending verification email" : "Resend Email"

                    contentItem: RowLayout {
                        spacing: 10
                        Item { Layout.fillWidth: true }

                        Item {
                            Layout.preferredWidth: 22
                            Layout.preferredHeight: 22
                            visible: root.resendLoading

                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                radius: width / 2
                                border.width: 2.5
                                border.color: Qt.rgba(root.primaryColor.r, root.primaryColor.g, root.primaryColor.b, 0.3)
                            }

                            Canvas {
                                id: resendSpinnerArc
                                anchors.fill: parent
                                property real spinAngle

                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.clearRect(0, 0, width, height)
                                    ctx.strokeStyle = root.primaryColor.toString()
                                    ctx.lineWidth = 2.5
                                    ctx.lineCap = "round"
                                    ctx.beginPath()
                                    var startAngle = spinAngle * Math.PI / 180
                                    var endAngle = startAngle + Math.PI * 0.75
                                    ctx.arc(width/2, height/2, width/2 - 2, startAngle, endAngle)
                                    ctx.stroke()
                                }

                                NumberAnimation on spinAngle {
                                    from: 0; to: 360
                                    duration: 1000
                                    loops: Animation.Infinite
                                    running: root.resendLoading
                                }

                                onSpinAngleChanged: requestPaint()
                            }
                        }

                        Text {
                            text: root.resendLoading ? "Sending..." : "Resend Email"
                            font.family: "Montserrat"
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                            font.letterSpacing: 0.3
                            color: resendBtn.enabled ? root.primaryColor : Qt.rgba(root.primaryColor.r, root.primaryColor.g, root.primaryColor.b, 0.5)
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        Item { Layout.fillWidth: true }
                    }

                    background: Rectangle {
                        color: resendBtn.pressed ? Qt.rgba(root.primaryColor.r, root.primaryColor.g, root.primaryColor.b, 0.12) :
                               resendBtn.hovered ? Qt.rgba(root.primaryColor.r, root.primaryColor.g, root.primaryColor.b, 0.08) :
                               "transparent"
                        radius: 27
                        border.color: resendBtn.enabled ?
                                      (resendBtn.hovered ? root.primaryHover : root.primaryColor) :
                                      Qt.rgba(root.primaryColor.r, root.primaryColor.g, root.primaryColor.b, 0.4)
                        border.width: 1.5
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }
                        layer.enabled: false
                        scale: resendBtn.pressed ? 0.98 : 1
                        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                    }

                    HoverHandler {
                        cursorShape: resendBtn.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    }

                    onClicked: {
                        root.resendErrorMessage = ""
                        root.resendSuccess = false
                        root.resendLoading = true
                        AirPCApiClient.resendVerification(root.registeredEmail)
                    }
                }

                // ── Back to Login button (primary) ────────────────────
                Button {
                    id: backToLoginBtn
                    Layout.fillWidth: true
                    Layout.preferredHeight: 54
                    Layout.bottomMargin: 16

                    Accessible.role: Accessible.Button
                    Accessible.name: "Back to Login"

                    contentItem: Text {
                        text: "Back to Login"
                        font.family: "Montserrat"
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0.3
                        color: "#FFFFFF"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    background: Rectangle {
                        color: {
                            if (backToLoginBtn.pressed) return root.primaryPressed
                            if (backToLoginBtn.hovered) return root.primaryHover
                            return root.primaryColor
                        }
                        radius: 27
                        Behavior on color { ColorAnimation { duration: 150 } }
                        layer.enabled: false
                        scale: backToLoginBtn.pressed ? 0.98 : 1
                        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                    }

                    HoverHandler { cursorShape: Qt.PointingHandCursor }

                    onClicked: App.Router.back()
                }
            } // end success ColumnLayout
        } // end Flickable
    } // end signupCard

    // ── Keyboard shortcut ──────────────────────────────────────────────
    Shortcut {
        sequence: "Return"
        enabled: !root.signupLoading && root.viewState === "form" &&
                 (usernameInput.activeFocus || emailInput.activeFocus ||
                  passwordInput.activeFocus || confirmPasswordInput.activeFocus)
        onActivated: signupBtn.clicked()
    }

    // ── API signal connections ─────────────────────────────────────────
    Connections {
        target: AirPCApiClient

        function onSignupSuccess(registeredEmail) {
            console.log("SignupView: Signup successful for", registeredEmail)
            root.signupLoading = false
            root.registeredEmail = registeredEmail
            root.viewState = "success"
        }

        function onSignupFailed(error) {
            console.log("SignupView: Signup failed -", error)
            root.signupLoading = false
            root.errorMessage = error
            shakeAnimation.start()
        }

        function onResendVerificationSuccess() {
            console.log("SignupView: Verification email resent successfully")
            root.resendLoading = false
            root.resendSuccess = true
            root.resendErrorMessage = ""
        }

        function onResendVerificationFailed(error) {
            console.log("SignupView: Resend verification failed -", error)
            root.resendLoading = false
            root.resendErrorMessage = error
            root.resendSuccess = false
        }
    }

    // ── Initial focus ──────────────────────────────────────────────────
    Component.onCompleted: {
        usernameInput.forceActiveFocus()
    }
}
