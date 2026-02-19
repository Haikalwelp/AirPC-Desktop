import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

import AirPCApiClient 1.0
import "." as App

FocusScope {
    id: root
    objectName: "ForgotPasswordView"

    // Design System Colors (identical to AirPCLoginView)
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

    // View state machine: "form" | "success"
    property string viewState: "form"

    // Local loading flag — does NOT use global AirPCApiClient.isLoading
    property bool forgotLoading: false

    property string errorMessage: ""

    // Background Gradient
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

    // Card with entrance animation
    Rectangle {
        id: forgotCard
        width: Math.min(parent.width * 0.9, 420)
        height: Math.min(parent.height * 0.95, contentLayout.implicitHeight + 64)
        anchors.centerIn: parent

        // Glassmorphism
        color: root.cardBackground
        radius: 20
        border.color: Qt.rgba(1, 1, 1, 0.3)
        border.width: 1.5

        // Entrance animation starts from transparent + scaled down
        opacity: 0
        scale: 0.95

        Component.onCompleted: {
            entranceAnimation.start()
        }

        ParallelAnimation {
            id: entranceAnimation
            NumberAnimation { target: forgotCard; property: "opacity"; to: 1; duration: 400; easing.type: Easing.OutCubic }
            NumberAnimation { target: forgotCard; property: "scale"; to: 1; duration: 400; easing.type: Easing.OutBack; easing.overshoot: 1.02 }
        }

        layer.enabled: false

        // ── Card Content ──────────────────────────────────────────────────────────
        ColumnLayout {
            id: contentLayout
            anchors.fill: parent
            anchors.margins: 32
            spacing: 24

            // ── FORM STATE ───────────────────────────────────────────────────────
            ColumnLayout {
                id: formContent
                Layout.fillWidth: true
                spacing: 24
                visible: root.viewState === "form"

                // Header
                ColumnLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 16

                    // Icon wrapper
                    Rectangle {
                        id: formIconWrapper
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 72
                        Layout.preferredHeight: 72
                        radius: 36
                        color: Qt.rgba(root.primaryColor.r, root.primaryColor.g, root.primaryColor.b, 0.12)

                        Behavior on color { ColorAnimation { duration: 200 } }

                        // Key icon as form-state icon
                        Image {
                            id: keyIcon
                            source: "qrc:/res/baseline-error_outline-24px.svg"
                            width: 36
                            height: 36
                            anchors.centerIn: parent
                            visible: false
                        }

                        MultiEffect {
                            anchors.fill: keyIcon
                            anchors.centerIn: parent
                            width: 36
                            height: 36
                            source: keyIcon
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
                            text: "Forgot Password?"
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
                            text: "Enter your email and we'll send a reset link."
                            font.family: "Montserrat"
                            font.pixelSize: 13
                            font.weight: Font.Normal
                            color: Qt.rgba(1, 1, 1, 0.9)
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            Layout.alignment: Qt.AlignHCenter
                            Layout.maximumWidth: 320

                            Accessible.role: Accessible.StaticText
                            Accessible.name: text
                        }
                    }
                }

                // Form fields
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 20

                    // Email Field
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Label {
                            text: "Email Address"
                            color: root.textPrimary
                            font.family: "Montserrat"
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }

                        // Custom input wrapper (matches AirPCLoginView pattern exactly)
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 56

                            Rectangle {
                                id: emailBg
                                anchors.fill: parent
                                color: emailInput.activeFocus ? root.inputBackgroundFocus :
                                       emailInputArea.containsMouse ? root.inputBackgroundHover : root.inputBackground
                                border.color: emailInput.activeFocus ? root.primaryColor : root.borderDefault
                                border.width: emailInput.activeFocus ? 2 : 1
                                radius: 12

                                Behavior on border.color { ColorAnimation { duration: 150 } }
                                Behavior on border.width { NumberAnimation { duration: 100 } }
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }

                            // Static placeholder
                            Text {
                                id: emailPlaceholder
                                anchors.left: parent.left
                                anchors.leftMargin: 16
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Enter your email"
                                font.family: "Montserrat"
                                font.pixelSize: 16
                                color: root.textMuted
                                visible: emailInput.text.length === 0 && !emailInput.activeFocus

                                Behavior on opacity { NumberAnimation { duration: 100 } }
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
                                enabled: !root.forgotLoading
                                focus: true
                                clip: true
                                inputMethodHints: Qt.ImhEmailCharactersOnly

                                Accessible.role: Accessible.EditableText
                                Accessible.name: "Email address input"
                                Accessible.description: "Enter your email address"

                                onAccepted: submitBtn.clicked()
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
                    }
                }

                // Error Message
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
                    id: submitBtn
                    Layout.fillWidth: true
                    Layout.preferredHeight: 54
                    Layout.topMargin: 8
                    enabled: !root.forgotLoading

                    Accessible.role: Accessible.Button
                    Accessible.name: root.forgotLoading ? "Sending reset link" : "Send Reset Link"

                    contentItem: RowLayout {
                        spacing: 10
                        Item { Layout.fillWidth: true }

                        // Loading Spinner
                        Item {
                            Layout.preferredWidth: 22
                            Layout.preferredHeight: 22
                            visible: root.forgotLoading

                            Rectangle {
                                id: spinnerRing
                                anchors.fill: parent
                                color: "transparent"
                                radius: width / 2
                                border.width: 2.5
                                border.color: Qt.rgba(1, 1, 1, 0.3)
                            }

                            Canvas {
                                id: spinnerArc
                                anchors.fill: parent

                                property real arcAngle: 0

                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.clearRect(0, 0, width, height)
                                    ctx.strokeStyle = "white"
                                    ctx.lineWidth = 2.5
                                    ctx.lineCap = "round"
                                    ctx.beginPath()
                                    var startAngle = arcAngle * Math.PI / 180
                                    var endAngle = startAngle + Math.PI * 0.75
                                    ctx.arc(width/2, height/2, width/2 - 2, startAngle, endAngle)
                                    ctx.stroke()
                                }

                                onArcAngleChanged: requestPaint()

                                Timer {
                                    interval: 16
                                    repeat: true
                                    running: root.forgotLoading
                                    onTriggered: spinnerArc.arcAngle = (spinnerArc.arcAngle + 6) % 360
                                }
                            }
                        }

                        Text {
                            text: root.forgotLoading ? "Sending..." : "Send Reset Link"
                            font.family: "Montserrat"
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                            font.letterSpacing: 0.3
                            color: "#FFFFFF"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    background: Rectangle {
                        id: submitBtnBg
                        color: {
                            if (!submitBtn.enabled) return Qt.rgba(root.primaryColor.r, root.primaryColor.g, root.primaryColor.b, 0.5)
                            if (submitBtn.pressed) return root.primaryPressed
                            if (submitBtn.hovered) return root.primaryHover
                            return root.primaryColor
                        }
                        radius: 27

                        Behavior on color { ColorAnimation { duration: 150 } }

                        layer.enabled: false

                        scale: submitBtn.pressed ? 0.98 : 1
                        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                    }

                    HoverHandler {
                        cursorShape: submitBtn.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    }

                    onClicked: {
                        if (emailInput.text.trim() === "") {
                            root.errorMessage = "Please enter your email address"
                            shakeAnimation.start()
                        } else {
                            root.errorMessage = ""
                            root.forgotLoading = true
                            AirPCApiClient.forgotPassword(emailInput.text.trim())
                        }
                    }
                }

                // "Remember your password? Sign in" footer
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 12
                    spacing: 4

                    Text {
                        text: "Remember your password?"
                        color: root.textSecondary
                        font.family: "Montserrat"
                        font.pixelSize: 13
                    }

                    AbstractButton {
                        id: signInLink

                        Accessible.role: Accessible.Link
                        Accessible.name: "Sign in"

                        contentItem: Text {
                            id: signInLinkText
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
                                color: signInLinkText.color
                                opacity: signInLink.hovered ? 1 : 0

                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }
                        }

                        onClicked: App.Router.back()

                        HoverHandler {
                            cursorShape: Qt.PointingHandCursor
                        }
                    }
                }
            } // end formContent

            // ── SUCCESS STATE ────────────────────────────────────────────────────
            ColumnLayout {
                id: successContent
                Layout.fillWidth: true
                spacing: 24
                visible: root.viewState === "success"

                // Header
                ColumnLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 16

                    // Mail / envelope icon wrapper
                    Rectangle {
                        id: successIconWrapper
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 72
                        Layout.preferredHeight: 72
                        radius: 36
                        color: Qt.rgba(root.primaryColor.r, root.primaryColor.g, root.primaryColor.b, 0.12)

                        // Use the visibility icon as mail-envelope stand-in (per spec fallback)
                        Image {
                            id: mailIcon
                            source: "qrc:/res/ic_visibility_white_48px.svg"
                            width: 36
                            height: 36
                            anchors.centerIn: parent
                            visible: false
                        }

                        MultiEffect {
                            anchors.fill: mailIcon
                            anchors.centerIn: parent
                            width: 36
                            height: 36
                            source: mailIcon
                            colorization: 1.0
                            colorizationColor: root.primaryColor
                        }

                        // Entrance bounce when state switches
                        SequentialAnimation {
                            id: successIconBounce
                            NumberAnimation { target: successIconWrapper; property: "scale"; from: 0.5; to: 1.0; duration: 350; easing.type: Easing.OutBack; easing.overshoot: 1.5 }
                        }
                    }

                    // Title & subtitle
                    ColumnLayout {
                        spacing: 8
                        Layout.alignment: Qt.AlignHCenter

                        Text {
                            text: "Check Your Email"
                            font.family: "Montserrat"
                            font.pixelSize: 26
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
                            // Mirror ForgotPasswordPage.tsx: "If an account exists for [email], we've sent …"
                            text: "If an account exists for <b>" + emailInput.text.trim() + "</b>, we've sent password reset instructions."
                            textFormat: Text.RichText
                            font.family: "Montserrat"
                            font.pixelSize: 13
                            color: Qt.rgba(1, 1, 1, 0.9)
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            Layout.alignment: Qt.AlignHCenter
                            Layout.maximumWidth: 320

                            Accessible.role: Accessible.StaticText
                            Accessible.name: text
                        }
                    }
                }

                // Instruction text
                Text {
                    text: "Click the link in the email to reset your password. The link will expire in 1 hour."
                    font.family: "Montserrat"
                    font.pixelSize: 13
                    color: Qt.rgba(1, 1, 1, 0.75)
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: true

                    Accessible.role: Accessible.StaticText
                    Accessible.name: text
                }

                // Button group — stacked vertically per spec
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    // "Try Different Email" — secondary/outline style
                    Button {
                        id: tryDifferentEmailBtn
                        Layout.fillWidth: true
                        Layout.preferredHeight: 54

                        Accessible.role: Accessible.Button
                        Accessible.name: "Try Different Email"

                        contentItem: Text {
                            text: "Try Different Email"
                            font.family: "Montserrat"
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            font.letterSpacing: 0.3
                            color: tryDifferentEmailBtn.pressed ? root.primaryPressed :
                                   tryDifferentEmailBtn.hovered ? root.primaryHover : root.primaryColor
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter

                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        background: Rectangle {
                            color: tryDifferentEmailBtn.pressed ? Qt.rgba(root.primaryColor.r, root.primaryColor.g, root.primaryColor.b, 0.1) :
                                   tryDifferentEmailBtn.hovered ? Qt.rgba(root.primaryColor.r, root.primaryColor.g, root.primaryColor.b, 0.06) :
                                   "transparent"
                            radius: 27
                            border.color: tryDifferentEmailBtn.pressed ? root.primaryPressed :
                                          tryDifferentEmailBtn.hovered ? root.primaryHover : root.primaryColor
                            border.width: 1.5

                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            scale: tryDifferentEmailBtn.pressed ? 0.98 : 1
                            Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                        }

                        HoverHandler {
                            cursorShape: Qt.PointingHandCursor
                        }

                        onClicked: {
                            root.viewState = "form"
                            root.errorMessage = ""
                            emailInput.text = ""
                            emailInput.forceActiveFocus()
                        }
                    }

                    // "Back to Sign In" — primary filled button
                    Button {
                        id: backToSignInBtn
                        Layout.fillWidth: true
                        Layout.preferredHeight: 54

                        Accessible.role: Accessible.Button
                        Accessible.name: "Back to Sign In"

                        contentItem: Text {
                            text: "Back to Sign In"
                            font.family: "Montserrat"
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            font.letterSpacing: 0.3
                            color: "#FFFFFF"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        background: Rectangle {
                            color: {
                                if (backToSignInBtn.pressed) return root.primaryPressed
                                if (backToSignInBtn.hovered) return root.primaryHover
                                return root.primaryColor
                            }
                            radius: 27

                            Behavior on color { ColorAnimation { duration: 150 } }

                            layer.enabled: false

                            scale: backToSignInBtn.pressed ? 0.98 : 1
                            Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                        }

                        HoverHandler {
                            cursorShape: Qt.PointingHandCursor
                        }

                        onClicked: App.Router.back()
                    }
                }
            } // end successContent

        } // end contentLayout
    } // end forgotCard

    // ── Keyboard Shortcut ────────────────────────────────────────────────────────
    Shortcut {
        sequence: "Return"
        enabled: !root.forgotLoading && root.viewState === "form" && emailInput.activeFocus
        onActivated: submitBtn.clicked()
    }

    // ── API Signal Connections ───────────────────────────────────────────────────
    Connections {
        target: AirPCApiClient

        function onForgotPasswordSuccess() {
            console.log("ForgotPasswordView: Reset email sent successfully.")
            root.forgotLoading = false
            root.viewState = "success"
            successIconBounce.start()
        }

        function onForgotPasswordFailed(error) {
            console.log("ForgotPasswordView: Reset email failed:", error)
            root.forgotLoading = false
            root.errorMessage = error
            shakeAnimation.start()
            emailInput.forceActiveFocus()
        }
    }

    // ── Initialisation ───────────────────────────────────────────────────────────
    Component.onCompleted: {
        emailInput.forceActiveFocus()
    }
}
