pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

import AirPCGameModel 1.0
import AirPCApiClient 1.0
import Session 1.0
import PlaytimeManager 1.0
import "." as App

Item {
    id: root
    objectName: "Game Library"

    // ============================================================================
    // Design System — matches GameLibraryPage.module.css + AirPC brand tokens
    // ============================================================================

    readonly property color primary:          "#8A1C5C"
    readonly property color primaryHover:     Qt.lighter("#8A1C5C", 1.12)
    readonly property color textOnDark:       "#FFFFFF"
    readonly property color textMutedOnDark:  Qt.rgba(1, 1, 1, 0.72)
    readonly property color textPrimary:      "#454545"
    readonly property color textMuted:        Qt.rgba(69/255, 69/255, 69/255, 0.6)

    // Glass tokens (matching CSS --control-bar-glass)
    readonly property color ctrlBarGlass:     Qt.rgba(1, 1, 1, 0.15)
    readonly property color ctrlBarGlassHov:  Qt.rgba(1, 1, 1, 0.20)
    readonly property color ctrlBarBorder:    Qt.rgba(1, 1, 1, 0.20)
    readonly property color searchBg:         Qt.rgba(0, 0, 0, 0.20)
    readonly property color searchBgFocus:    Qt.rgba(0, 0, 0, 0.30)
    readonly property color filterGroupBg:    Qt.rgba(0, 0, 0, 0.20)
    readonly property color sessionBannerBg:  Qt.rgba(0, 0, 0, 0.20)
    readonly property color sessionBorder:    Qt.rgba(1, 1, 1, 0.10)

    readonly property color danger:           "#F94141"
    readonly property color dangerBg:         Qt.rgba(249/255, 65/255, 65/255, 0.14)
    readonly property color dangerBorder:     Qt.rgba(249/255, 65/255, 65/255, 0.35)

    readonly property color resumeGreen:      "#34BD86"
    readonly property color resumeGreenDark:  "#239365"
    readonly property color endRed:           Qt.rgba(226/255, 99/255, 114/255, 0.14)
    readonly property color endRedBorder:     Qt.rgba(226/255, 99/255, 114/255, 0.60)
    readonly property color endRedText:       "#FFDADF"

    readonly property int pagePadding:    24
    readonly property int maxContentWidth: 1400

    // Responsive
    readonly property bool isNarrow: width < 768
    readonly property int  gridGap:   width < 640 ? 12 : (width < 1024 ? 24 : 32)
    readonly property int  cardWidth: width < 640 ? 150 : (width < 1024 ? 180 : 200)
    readonly property int  cardHeight: Math.round(cardWidth * 1.50)

    // State
    property string searchQuery:   ""
    property string selectedFilter: "all"   // "all" | "ready"
    property bool queueOverlayExpanded: true
    property bool showFundingChoiceModal: false
    property string fundingChoiceContext: ""   // "launch" | "claim"
    property string pendingLaunchGameUuid: ""
    property string pendingLaunchGameTitle: ""
    property int selectedSubscriptionInstanceId: 0
    property bool debugIconLogs: true
    property bool debugIconProbeEnabled: true
    property int debugIconProbeRemaining: 6

    readonly property var entitlements: AirPCApiClient.entitlements
    readonly property var queueState: AirPCApiClient.queueState
    readonly property int subscriptionSeconds: (entitlements && entitlements.subscriptionSeconds) ? entitlements.subscriptionSeconds : 0
    readonly property int availableVouchers: (entitlements && entitlements.availableVouchers) ? entitlements.availableVouchers : 0
    readonly property var activeVoucher: (entitlements && entitlements.activeVoucher !== undefined) ? entitlements.activeVoucher : null
    readonly property var subscriptions: (entitlements && entitlements.subscriptions) ? entitlements.subscriptions : []
    readonly property int recommendedSubscriptionInstanceID: (entitlements && entitlements.recommendedSubscriptionInstanceID) ? entitlements.recommendedSubscriptionInstanceID : 0
    readonly property bool hasVoucherPath: availableVouchers > 0 || activeVoucher !== null
    readonly property bool hasSubscriptionPath: subscriptionSeconds > 0
    readonly property bool shouldPromptFundingChoice: hasSubscriptionPath && hasVoucherPath

    readonly property bool queueInQueue: queueState && queueState.inQueue
    readonly property string queueGameTitle: queueState && queueState.gameTitle ? queueState.gameTitle : ""
    readonly property int queuePosition: queueState && queueState.position ? queueState.position : 0
    readonly property string queueClaimToken: queueState && queueState.claimToken ? queueState.claimToken : ""
    readonly property int queueExpiresInSeconds: queueState && queueState.expiresInSeconds ? queueState.expiresInSeconds : 0
    readonly property bool queueReady: queueInQueue && queueClaimToken.length > 0

    function resolveDefaultFundingSource() {
        if (activeVoucher !== null) {
            return "voucher"
        }
        if (subscriptionSeconds > 0) {
            return "subscription"
        }
        if (availableVouchers > 0) {
            return "voucher"
        }
        return ""
    }

    function resolveDefaultSubscriptionInstanceID() {
        if (selectedSubscriptionInstanceId > 0) {
            return selectedSubscriptionInstanceId
        }
        if (recommendedSubscriptionInstanceID > 0) {
            return recommendedSubscriptionInstanceID
        }
        if (subscriptions && subscriptions.length > 0 && subscriptions[0].subscription_instance_id) {
            return subscriptions[0].subscription_instance_id
        }
        return 0
    }

    function probeIconUrl(url, title, uuid) {
        if (!debugIconLogs || !debugIconProbeEnabled) {
            return
        }
        if (!url || url.length === 0) {
            return
        }
        if (debugIconProbeRemaining <= 0) {
            return
        }

        debugIconProbeRemaining = debugIconProbeRemaining - 1

        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) {
                return
            }

            var contentType = ""
            try {
                contentType = xhr.getResponseHeader("Content-Type")
            } catch (err) {
                contentType = ""
            }

            console.info("[ICON-DEBUG] Probe result",
                         "title=", title,
                         "uuid=", uuid,
                         "status=", xhr.status,
                         "contentType=", contentType,
                         "responseBytes=", xhr.responseText ? xhr.responseText.length : 0,
                         "url=", url)
        }

        xhr.open("GET", url)
        xhr.send()
    }

    function launchGame(gameUuid, gameTitle) {
        if (!hasSubscriptionPath && !hasVoucherPath) {
            App.Router.switchTab("playtime")
            return
        }

        pendingLaunchGameUuid = gameUuid
        pendingLaunchGameTitle = gameTitle

        if (shouldPromptFundingChoice) {
            fundingChoiceContext = "launch"
            showFundingChoiceModal = true
            return
        }

        var source = resolveDefaultFundingSource()
        if (source === "") {
            App.Router.switchTab("playtime")
            return
        }

        var subId = source === "subscription" ? resolveDefaultSubscriptionInstanceID() : 0
        AirPCApiClient.launchSharedPoolGame(gameUuid, gameTitle, source, subId)
    }

    function claimQueuedGame() {
        if (!queueClaimToken || queueClaimToken.length === 0) {
            return
        }

        if (shouldPromptFundingChoice) {
            fundingChoiceContext = "claim"
            showFundingChoiceModal = true
            return
        }

        var source = resolveDefaultFundingSource()
        if (source === "") {
            App.Router.switchTab("playtime")
            return
        }

        var subId = source === "subscription" ? resolveDefaultSubscriptionInstanceID() : 0
        AirPCApiClient.claimQueue(queueClaimToken, source, subId)
    }

    function applyFundingChoice(source) {
        showFundingChoiceModal = false

        var subId = source === "subscription" ? resolveDefaultSubscriptionInstanceID() : 0
        if (fundingChoiceContext === "launch") {
            AirPCApiClient.launchSharedPoolGame(pendingLaunchGameUuid, pendingLaunchGameTitle, source, subId)
            return
        }

        if (fundingChoiceContext === "claim") {
            AirPCApiClient.claimQueue(queueClaimToken, source, subId)
        }
    }

    // Signals
    signal streamLaunched(string sessionId, string streamHost, int streamPort, int httpsPort)
    signal logoutRequested()

    // ============================================================================
    // Inline Components
    // ============================================================================

    // Circular glass icon button (matches .refreshButton)
    component GlassOrbButton: ToolButton {
        id: orb
        property string tooltip: ""
        implicitWidth:  40
        implicitHeight: 40

        background: Rectangle {
            radius: 20
            color:  orb.down    ? Qt.rgba(1, 1, 1, 0.24)
                  : orb.hovered ? Qt.rgba(1, 1, 1, 0.20)
                  :               Qt.rgba(1, 1, 1, 0.10)
            border.color: Qt.rgba(1, 1, 1, 0.20)
            border.width: 1

            Behavior on color { ColorAnimation { duration: 150 } }

            // Subtle rotation hint on hover (matches CSS rotate(15deg))
            rotation: orb.hovered && !orb.down ? 15 : 0
            Behavior on rotation { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

            layer.enabled: orb.hovered
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.rgba(1, 1, 1, 0.12)
                shadowVerticalOffset: 0
                shadowBlur: 0.6
            }
        }

        ToolTip.visible: tooltip.length > 0 && hovered
        ToolTip.text: tooltip
        ToolTip.delay: 800
    }

    // Segmented filter button (sits inside the pill group)
    component FilterButton: AbstractButton {
        id: fb
        property bool isActive: false

        implicitHeight: 34
        leftPadding: 20
        rightPadding: 20

        contentItem: Text {
            text: fb.text
            font.pixelSize: 12
            font.weight: Font.DemiBold
            font.family: "Montserrat"
            font.letterSpacing: 0.5
            color: fb.isActive ? "#FFFFFF" : Qt.rgba(1, 1, 1, 0.60)
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter

            Behavior on color { ColorAnimation { duration: 180 } }
        }

        background: Item {}   // Group handles the sliding pill

        HoverHandler { cursorShape: Qt.PointingHandCursor }
    }

    // Game card (matches web GameCard — cover image + gradient overlay + play orb)
    component GameCard: Item {
        id: card
        property string gameTitle:     ""
        property string gameAppUuid:   ""
        property string gameImageUrl:  ""
        property color  accentColor: "#8A1C5C"   // pass root.primary at instantiation if needed
        signal clicked()

        property bool _hovered: mouseArea.containsMouse
        property bool _pressed:  mouseArea.pressed

        opacity: 0
        scale: _pressed ? 0.978 : (_hovered ? 1.02 : 1.0)
        // Use transform translate instead of y to avoid disturbing grid layout
        transform: Translate { y: card._hovered ? -6 : 0; Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } } }

        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

        Component.onCompleted: appearAnim.start()
        NumberAnimation {
            id: appearAnim
            target: card
            property: "opacity"
            to: 1
            duration: 220
            easing.type: Easing.OutCubic
        }

        Rectangle {
            id: frame
            anchors.fill: parent
            radius: 16
            clip: true
            color: Qt.rgba(1, 1, 1, 0.10)
            border.color: card._hovered
                ? Qt.rgba(138/255, 28/255, 92/255, 0.50)
                : Qt.rgba(1, 1, 1, 0.18)
            border.width: 1.5

            Behavior on border.color { ColorAnimation { duration: 180 } }

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.rgba(0, 0, 0, 0.14)
                shadowVerticalOffset: card._hovered ? 20 : 10
                shadowBlur: card._hovered ? 0.72 : 0.55
            }

            // Gradient placeholder background
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(138/255, 28/255, 92/255, 0.18) }
                    GradientStop { position: 1.0; color: Qt.rgba(23/255, 72/255, 113/255, 0.28) }
                }
            }

            // Cover image
            Image {
                id: coverImg
                anchors.fill: parent
                source: card.gameImageUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                scale: card._hovered ? 1.06 : 1.0
                opacity: (status === Image.Ready) ? 1.0 : 0.0

                Behavior on scale   { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                onSourceChanged: {
                    if (!root.debugIconLogs) {
                        return
                    }

                    var sourceText = source ? source.toString() : ""

                    if (!sourceText || sourceText.length === 0) {
                        console.warn("[ICON-DEBUG] Empty source", "title=", card.gameTitle, "uuid=", card.gameAppUuid)
                    } else {
                        console.info("[ICON-DEBUG] Source set", "title=", card.gameTitle, "uuid=", card.gameAppUuid, "source=", sourceText)
                        root.probeIconUrl(sourceText, card.gameTitle, card.gameAppUuid)
                    }
                }

                onStatusChanged: {
                    if (root.debugIconLogs && status !== Image.Null) {
                        console.info("[ICON-DEBUG] Status changed", "title=", card.gameTitle, "uuid=", card.gameAppUuid, "status=", status, "source=", source)
                    }

                    if (status === Image.Error) {
                        console.warn("[ICON-DEBUG] Load failed", "title=", card.gameTitle, "uuid=", card.gameAppUuid, "source=", source)
                        return
                    }

                    if (root.debugIconLogs && status === Image.Ready) {
                        console.info("[ICON-DEBUG] Load ready", "title=", card.gameTitle, "uuid=", card.gameAppUuid, "source=", source,
                                     "sourceSize=", sourceSize.width + "x" + sourceSize.height)
                    }
                }
            }

            // Loading / placeholder state
            Item {
                anchors.fill: parent
                visible: coverImg.status !== Image.Ready

                BusyIndicator {
                    anchors.centerIn: parent
                    running: coverImg.status === Image.Loading
                    visible: coverImg.status === Image.Loading
                    width: 28; height: 28
                }

                Image {
                    anchors.centerIn: parent
                    source: "qrc:/res/ic_videogame_asset_white_48px.svg"
                    width: 42; height: 42
                    visible: coverImg.status !== Image.Loading
                    opacity: 0.30
                }
            }

            // Bottom gradient + title overlay
            Rectangle {
                anchors.left:   parent.left
                anchors.right:  parent.right
                anchors.bottom: parent.bottom
                height: 80
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.0)  }
                    GradientStop { position: 0.4; color: Qt.rgba(0, 0, 0, 0.55) }
                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.90) }
                }

                Text {
                    anchors.left:         parent.left
                    anchors.right:        parent.right
                    anchors.bottom:       parent.bottom
                    anchors.leftMargin:   12
                    anchors.rightMargin:  12
                    anchors.bottomMargin: 10
                    text: card.gameTitle
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    font.family: "Montserrat"
                    color: "#FFFFFF"
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.Wrap
                }
            }

            // Play orb overlay (web play button reveal)
            Rectangle {
                width: 54; height: 54
                radius: 27
                anchors.centerIn: parent
                color: card.accentColor
                opacity: card._hovered ? 1.0 : 0.0
                scale:  card._hovered ? 1.0 : 0.72

                Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic  } }
                Behavior on scale   { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.08 } }

                layer.enabled: card._hovered
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Qt.rgba(138/255, 28/255, 92/255, 0.45)
                    shadowVerticalOffset: 10
                    shadowBlur: 0.72
                }

                Image {
                    anchors.centerIn: parent
                    source: "qrc:/res/play_arrow_FILL1_wght700_GRAD200_opsz48.svg"
                    width: 28; height: 28
                    opacity: 0.95
                }
            }

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: card.clicked()
            }
        }
    }

    // Section divider title (pearlescent gradient + fading rule — matches .sectionTitle)
    component SectionTitle: RowLayout {
        id: st
        property string text:      ""
        property color  textColor: "#FFFFFF"
        spacing: 16
        Layout.fillWidth: true

        Text {
            text: st.text
            font.pixelSize: 20
            font.weight: Font.Bold
            font.family: "Montserrat"
            font.letterSpacing: -0.4
            color: st.textColor

            layer.enabled: true
            layer.effect: MultiEffect {
                colorization: 0.08
                colorizationColor: "#E2E2E2"
            }
        }

        // Fading divider rule
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            Layout.alignment: Qt.AlignVCenter
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.35) }
                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.08) }
                GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.00) }
            }
        }
    }

    // Active session banner (matches .activeSessionBanner)
    component ActiveSessionBanner: Rectangle {
        id: banner
        property var  session:     null
        property bool narrow:      false
        // Color props — set at instantiation site to avoid root-reference issues
        property color accentGreen:     "#34BD86"
        property color accentGreenDark: "#239365"
        property color redText:         "#FFDADF"
        property color redBg:           Qt.rgba(226/255, 99/255, 114/255, 0.14)
        property color redBorder:       Qt.rgba(226/255, 99/255, 114/255, 0.60)

        signal resumeClicked()
        signal endClicked()

        implicitHeight: banner.narrow ? bannerContent.implicitHeight + 40 : 72
        radius: 20
        color: Qt.rgba(0, 0, 0, 0.20)
        border.color: Qt.rgba(1, 1, 1, 0.10)
        border.width: 1

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.20)
            shadowVerticalOffset: 8
            shadowBlur: 0.60
        }

        ColumnLayout {
            id: bannerContent
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    Text {
                        text: "ACTIVE SESSION"
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        font.family: "Montserrat"
                        font.letterSpacing: 0.8
                        color: Qt.rgba(1, 1, 1, 0.60)
                    }
                    Text {
                        text: banner.session
                            ? ((banner.session.appName || "Current game") + " · " + banner.session.computerName)
                            : ""
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        font.family: "Montserrat"
                        color: Qt.rgba(1, 1, 1, 0.92)
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                // Time remaining badge
                Rectangle {
                    visible: PlaytimeManager.isSessionActive
                    radius: 8
                    color: Qt.rgba(0, 0, 0, 0.20)
                    border.color: PlaytimeManager.remainingSeconds < 300
                        ? Qt.rgba(239/255, 68/255, 68/255, 0.50)
                        : Qt.rgba(34/255, 197/255, 94/255, 0.50)
                    border.width: 1
                    implicitWidth: timeText.implicitWidth + 16
                    implicitHeight: 28

                    Text {
                        id: timeText
                        anchors.centerIn: parent
                        text: PlaytimeManager.formattedRemaining
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        font.family: "Montserrat"
                        color: PlaytimeManager.remainingSeconds < 300 ? "#ef4444" : "#22c55e"
                    }
                }

                // Resume button
                Button {
                    id: resumeBtn
                    implicitWidth: 86
                    implicitHeight: 34

                    contentItem: Text {
                        text: "Resume"
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        font.family: "Montserrat"
                        color: "#FFFFFF"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    background: Rectangle {
                        radius: 10
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: banner.accentGreen }
                            GradientStop { position: 1.0; color: banner.accentGreenDark }
                        }
                        border.color: Qt.rgba(45/255, 173/255, 122/255, 0.60)
                        border.width: 1
                        scale: resumeBtn.pressed ? 0.97 : (resumeBtn.hovered ? 1.02 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 120 } }

                        layer.enabled: resumeBtn.hovered
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: Qt.rgba(45/255, 173/255, 122/255, 0.30)
                            shadowVerticalOffset: 6
                            shadowBlur: 0.65
                        }
                    }

                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    onClicked: banner.resumeClicked()
                }

                // End session button
                Button {
                    id: endBtn
                    implicitWidth: 96
                    implicitHeight: 34

                    contentItem: Text {
                        text: "End Session"
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        font.family: "Montserrat"
                        color: banner.redText
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    background: Rectangle {
                        radius: 10
                        color: endBtn.hovered ? Qt.rgba(226/255, 99/255, 114/255, 0.24)
                                              : banner.redBg
                        border.color: banner.redBorder
                        border.width: 1
                        scale: endBtn.pressed ? 0.97 : (endBtn.hovered ? 1.02 : 1.0)
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on scale { NumberAnimation { duration: 120 } }
                    }

                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    onClicked: banner.endClicked()
                }
            }
        }
    }

    // ============================================================================
    // Background gradient (matches .container background)
    // ============================================================================

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0;  color: "#DED1C6" }
            GradientStop { position: 0.33; color: "#A77693" }
            GradientStop { position: 0.66; color: "#174871" }
            GradientStop { position: 1.0;  color: "#0F2D4D" }
        }
    }

    // ============================================================================
    // Page layout — Flickable for scrolling content
    // ============================================================================

    Flickable {
        id: pageFlick
        anchors.fill: parent
        clip: true
        flickableDirection: Flickable.VerticalFlick
        contentWidth: width
        contentHeight: pageCol.implicitHeight + root.pagePadding * 2

        // Scrollbar hidden — no visible scrollbar on the page
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AlwaysOff }

        ColumnLayout {
            id: pageCol
            // Always horizontally centered; pad from edge but never exceed maxContentWidth
            y: root.pagePadding
            x: Math.max(root.pagePadding, (pageFlick.width - pageCol.width) / 2)
            width: Math.min(pageFlick.width - root.pagePadding * 2, root.maxContentWidth)
            spacing: 0

            // ----------------------------------------------------------------
            // STICKY CONTROL BAR  (matches .controls — pill on desktop)
            // ----------------------------------------------------------------
            Rectangle {
                id: controlBar
                Layout.fillWidth: true
                Layout.maximumWidth: 800
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: 28
                Layout.topMargin: 16

                // Cache height as a local property so radius can reference it cleanly
                readonly property int barHeight: root.isNarrow ? ctrlNarrow.implicitHeight + 32 : 56
                Layout.preferredHeight: barHeight
                radius: root.isNarrow ? 20 : barHeight / 2  // true pill on desktop

                color: ctrlHover.hovered ? root.ctrlBarGlassHov : root.ctrlBarGlass
                border.color: ctrlHover.hovered
                    ? Qt.rgba(1, 1, 1, 0.30)
                    : root.ctrlBarBorder
                border.width: 1

                Behavior on color        { ColorAnimation { duration: 200 } }
                Behavior on border.color { ColorAnimation { duration: 200 } }

                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Qt.rgba(0, 0, 0, 0.20)
                    shadowVerticalOffset: 8
                    shadowBlur: 0.65
                }

                HoverHandler { id: ctrlHover }

                // ---------- Desktop layout (single row pill) ----------
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 32
                    anchors.rightMargin: 32
                    spacing: 16
                    visible: !root.isNarrow

                    // Etched-glass search input — fills available space up to 320px
                    Item {
                        Layout.fillWidth: true
                        Layout.maximumWidth: 320
                        Layout.preferredHeight: 44

                        Rectangle {
                            anchors.fill: parent
                            radius: 22
                            color: searchWide.activeFocus ? root.searchBgFocus : root.searchBg
                            border.color: searchWide.activeFocus
                                ? Qt.rgba(138/255, 28/255, 92/255, 0.80)
                                : Qt.rgba(1, 1, 1, 0.10)
                            border.width: searchWide.activeFocus ? 2 : 1

                            Behavior on color        { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            // Inner shadow effect (inset box-shadow approximation)
                            layer.enabled: true
                            layer.effect: MultiEffect {
                                shadowEnabled: true
                                shadowColor: Qt.rgba(0, 0, 0, 0.10)
                                shadowVerticalOffset: 2
                                shadowBlur: 0.40
                            }
                        }

                        Image {
                            anchors.left: parent.left
                            anchors.leftMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            source: "qrc:/res/search.svg"
                            width: 18; height: 18
                            opacity: 0.50
                        }

                        TextInput {
                            id: searchWide
                            anchors.fill: parent
                            anchors.leftMargin: 44
                            anchors.rightMargin: 16
                            verticalAlignment: TextInput.AlignVCenter
                            font.pixelSize: 14
                            font.family: "Montserrat"
                            color: root.textOnDark
                            clip: true
                            selectByMouse: true

                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                text: "Search games..."
                                font: parent.font
                                color: Qt.rgba(1, 1, 1, 0.40)
                                visible: parent.text.length === 0 && !parent.activeFocus
                            }

                            onTextChanged: root.searchQuery = text
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Loading text
                    Text {
                        visible: gameModelInstance.loading
                        text: "Loading games..."
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        font.family: "Montserrat"
                        font.letterSpacing: 0.5
                        color: Qt.rgba(1, 1, 1, 0.60)
                    }

                    // Segmented filter group (matches .filterGroup with sliding pill)
                    Item {
                        implicitWidth: filterRow.implicitWidth + 8
                        implicitHeight: 42

                        Rectangle {
                            anchors.fill: parent
                            radius: 24
                            color: root.filterGroupBg
                            border.color: Qt.rgba(1, 1, 1, 0.05)
                            border.width: 1
                        }

                        // Sliding pill indicator
                        Rectangle {
                            id: slidingPill
                            y: 4
                            height: parent.height - 8
                            width: root.selectedFilter === "all" ? allBtn.width : readyBtn.width
                            x: root.selectedFilter === "all"
                                ? allBtn.x + 4
                                : readyBtn.x + 4
                            radius: 20
                            color: root.primary

                            Behavior on x     { NumberAnimation { duration: 380; easing.type: Easing.OutBack; easing.overshoot: 0.85 } }
                            Behavior on width { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

                            layer.enabled: true
                            layer.effect: MultiEffect {
                                shadowEnabled: true
                                shadowColor: Qt.rgba(138/255, 28/255, 92/255, 0.30)
                                shadowVerticalOffset: 2
                                shadowBlur: 0.55
                            }
                        }

                        Row {
                            id: filterRow
                            anchors.centerIn: parent
                            spacing: 0

                            FilterButton {
                                id: allBtn
                                text: "ALL GAMES"
                                isActive: root.selectedFilter === "all"
                                onClicked: root.selectedFilter = "all"
                            }
                            FilterButton {
                                id: readyBtn
                                text: "READY TO PLAY"
                                isActive: root.selectedFilter === "ready"
                                onClicked: root.selectedFilter = "ready"
                            }
                        }
                    }

                    // Circular refresh orb
                    GlassOrbButton {
                        tooltip: "Refresh Library"
                        icon.source: "qrc:/res/refresh.svg"
                        icon.width: 20; icon.height: 20
                        icon.color: Qt.rgba(1, 1, 1, 0.80)
                        enabled: !gameModelInstance.loading
                        opacity: gameModelInstance.loading ? 0.50 : 1.0
                        onClicked: gameModelInstance.refresh()
                    }
                }

                // ---------- Narrow layout (stacked) ----------
                ColumnLayout {
                    id: ctrlNarrow
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12
                    visible: root.isNarrow

                    // Search + inline refresh
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 44

                            Rectangle {
                                anchors.fill: parent
                                radius: 22
                                color: searchNarrow.activeFocus ? root.searchBgFocus : root.searchBg
                                border.color: searchNarrow.activeFocus
                                    ? Qt.rgba(138/255, 28/255, 92/255, 0.80)
                                    : Qt.rgba(1, 1, 1, 0.10)
                                border.width: searchNarrow.activeFocus ? 2 : 1
                                Behavior on color        { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }
                            }

                            Image {
                                anchors.left: parent.left
                                anchors.leftMargin: 14
                                anchors.verticalCenter: parent.verticalCenter
                                source: "qrc:/res/search.svg"
                                width: 18; height: 18
                                opacity: 0.50
                            }

                            TextInput {
                                id: searchNarrow
                                anchors.fill: parent
                                anchors.leftMargin: 44
                                anchors.rightMargin: 14
                                verticalAlignment: TextInput.AlignVCenter
                                font.pixelSize: 14
                                font.family: "Montserrat"
                                color: root.textOnDark
                                clip: true
                                selectByMouse: true

                                Text {
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    text: "Search games..."
                                    font: parent.font
                                    color: Qt.rgba(1, 1, 1, 0.40)
                                    visible: parent.text.length === 0 && !parent.activeFocus
                                }

                                onTextChanged: root.searchQuery = text
                            }
                        }

                        GlassOrbButton {
                            implicitWidth: 44; implicitHeight: 44
                            tooltip: "Refresh"
                            icon.source: "qrc:/res/refresh.svg"
                            icon.width: 20; icon.height: 20
                            icon.color: Qt.rgba(1, 1, 1, 0.80)
                            enabled: !gameModelInstance.loading
                            opacity: gameModelInstance.loading ? 0.50 : 1.0
                            onClicked: gameModelInstance.refresh()
                        }
                    }

                    // Filter pills row (scrollable)
                    Flickable {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        clip: true
                        flickableDirection: Flickable.HorizontalFlick
                        boundsBehavior: Flickable.StopAtBounds
                        contentWidth: narrowPills.width

                        Row {
                            id: narrowPills
                            spacing: 8

                            Repeater {
                                model: [
                                    { label: "ALL GAMES", value: "all"   },
                                    { label: "READY TO PLAY", value: "ready" }
                                ]
                                delegate: Rectangle {
                                    required property var modelData
                                    property bool isActive: root.selectedFilter === modelData.value
                                    height: 34
                                    radius: 20
                                    width: pillLabel.implicitWidth + 28
                                    color: isActive ? root.primary : Qt.rgba(1, 1, 1, 0.10)
                                    border.color: isActive ? root.primary : Qt.rgba(1, 1, 1, 0.10)
                                    border.width: 1

                                    Behavior on color        { ColorAnimation { duration: 150 } }
                                    Behavior on border.color { ColorAnimation { duration: 150 } }

                                    Text {
                                        id: pillLabel
                                        anchors.centerIn: parent
                                        text: parent.modelData.label
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                        font.family: "Montserrat"
                                        font.letterSpacing: 0.5
                                        color: root.textOnDark
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.selectedFilter = parent.modelData.value
                                    }
                                }
                            }
                        }

                        ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AlwaysOff }
                    }
                }
            }

            // ----------------------------------------------------------------
            // ACTIVE SESSION BANNER
            // ----------------------------------------------------------------
            ActiveSessionBanner {
                Layout.fillWidth: true
                Layout.bottomMargin: 20
                visible: AirPCApiClient.hasActiveSession
                narrow:  root.isNarrow
                session: AirPCApiClient.activeSession
                onResumeClicked: AirPCApiClient.resumeSession()
                onEndClicked:    endSessionDialog.open()
            }

            // ----------------------------------------------------------------
            // ERROR BANNER
            // ----------------------------------------------------------------
            Rectangle {
                Layout.fillWidth: true
                Layout.bottomMargin: 16
                implicitHeight: errRow.implicitHeight + 28
                visible: gameModelInstance.errorMessage !== "" && !gameModelInstance.loading
                radius: 16
                color: root.dangerBg
                border.color: root.dangerBorder
                border.width: 1

                RowLayout {
                    id: errRow
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 10

                    Text {
                        text: "Unable to load library"
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        font.family: "Montserrat"
                        color: root.danger
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: gameModelInstance.errorMessage
                        font.pixelSize: 12
                        font.family: "Montserrat"
                        color: Qt.rgba(1, 1, 1, 0.80)
                        elide: Text.ElideRight
                        Layout.maximumWidth: 260
                    }
                }
            }

            // ----------------------------------------------------------------
            // GAME GRID AREA — single ColumnLayout drives all states
            // ----------------------------------------------------------------
            ColumnLayout {
                id: gridArea
                Layout.fillWidth: true
                spacing: 0

                // ── Section title (only when there are games or loading) ──
                SectionTitle {
                    text: "Game Library"
                    textColor: root.textOnDark
                    Layout.fillWidth: true
                    Layout.bottomMargin: 20
                    visible: gameGrid.count > 0 || (gameModelInstance.loading && gameGrid.count === 0)
                }

                // ── Loading skeleton: Flow of shimmer cards ──
                Flow {
                    Layout.fillWidth: true
                    spacing: root.gridGap
                    visible: gameModelInstance.loading && gameGrid.count === 0

                    Repeater {
                        model: 8
                        Rectangle {
                            width: root.cardWidth
                            height: root.cardHeight
                            radius: 16
                            color: Qt.rgba(1, 1, 1, 0.08)
                            border.color: Qt.rgba(1, 1, 1, 0.10)
                            border.width: 1

                            SequentialAnimation on opacity {
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.35; duration: 900; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 0.85; duration: 900; easing.type: Easing.InOutSine }
                            }
                        }
                    }
                }

                // ── Empty state (centered, full-width container) ──
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: emptyCol.implicitHeight + 80
                    visible: !gameModelInstance.loading && gameGrid.count === 0

                    ColumnLayout {
                        id: emptyCol
                        anchors.centerIn: parent
                        spacing: 10

                        Image {
                            source: "qrc:/res/ic_videogame_asset_white_48px.svg"
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 64
                            Layout.preferredHeight: 64
                            opacity: 0.30
                        }

                        Text {
                            text: root.searchQuery.length > 0 ? "No games match your search" : "No games found"
                            font.pixelSize: 20
                            font.weight: Font.Bold
                            font.family: "Montserrat"
                            color: root.textOnDark
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Text {
                            text: root.searchQuery.length > 0
                                ? "Try a different search term"
                                : "No apps were returned from your allocations."
                            font.pixelSize: 14
                            font.family: "Montserrat"
                            color: root.textMutedOnDark
                            Layout.alignment: Qt.AlignHCenter
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                            Layout.maximumWidth: 360
                        }

                        Button {
                            id: emptyRefreshBtn
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: 16
                            visible: root.searchQuery.length === 0
                            implicitWidth: 140
                            implicitHeight: 44

                            contentItem: Text {
                                text: "Refresh"
                                font.pixelSize: 14
                                font.weight: Font.Medium
                                font.family: "Montserrat"
                                color: root.textOnDark
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            background: Rectangle {
                                radius: 22
                                color: emptyRefreshBtn.hovered ? root.primaryHover : root.primary
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }

                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                            onClicked: gameModelInstance.refresh()
                        }
                    }
                }

                // ── Actual game grid ──
                CenteredGridView {
                    id: gameGrid
                    Layout.fillWidth: true
                    // Height = rows * cellHeight, minus one gap (last row has no bottom gap)
                    implicitHeight: {
                        var cols = Math.max(1, Math.floor(width / (root.cardWidth + root.gridGap)))
                        var rows = Math.ceil(count / cols)
                        return rows > 0 ? rows * (root.cardHeight + root.gridGap) - root.gridGap : 0
                    }
                    visible: count > 0
                    clip: false        // outer Flickable clips; disabling here prevents card shadow cutoff
                    interactive: false // outer Flickable handles all scrolling

                    cellWidth:  root.cardWidth  + root.gridGap
                    cellHeight: root.cardHeight + root.gridGap

                    model: AirPCGameSortFilterModel {
                        id: sortFilterModel
                        sourceModel: gameModelInstance
                        filterText: root.searchQuery
                        filterStatus: root.selectedFilter
                    }

                    delegate: GameCard {
                        required property string title
                        required property string imageUrl
                        required property string appUuid
                        required property string status
                        required property int index

                        gameTitle: title
                        gameImageUrl: imageUrl
                        gameAppUuid: appUuid

                        width:  root.cardWidth
                        height: root.cardHeight

                        onClicked: {
                            console.log("Launching game:", title, appUuid, status)
                            root.launchGame(appUuid, title)
                        }
                    }
                }
            }

            // Bottom breathing room
            Item { Layout.preferredHeight: 64 }
        }
    }

    // ============================================================================
    // Queue overlays / badge
    // ============================================================================

    Rectangle {
        id: queueOverlay
        visible: root.queueInQueue && root.queueOverlayExpanded
        z: 20
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 22
        width: Math.min(root.width - 24, 460)
        implicitHeight: queueContent.implicitHeight + 22
        radius: 16
        color: Qt.rgba(20/255, 20/255, 30/255, 0.92)
        border.color: Qt.rgba(1, 1, 1, 0.20)
        border.width: 1

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.42)
            shadowVerticalOffset: 10
            shadowBlur: 0.7
        }

        ColumnLayout {
            id: queueContent
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            Text {
                text: root.queueReady ? "YOUR GAME IS READY" : "YOU ARE IN QUEUE"
                font.family: "Montserrat"
                font.pixelSize: 11
                font.weight: Font.Bold
                font.letterSpacing: 0.8
                color: Qt.rgba(1, 1, 1, 0.70)
            }

            Text {
                text: root.queueGameTitle
                font.family: "Montserrat"
                font.pixelSize: 16
                font.weight: Font.DemiBold
                color: "#FFFFFF"
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                visible: !root.queueReady
                text: "Position #" + root.queuePosition
                font.family: "Montserrat"
                font.pixelSize: 13
                color: Qt.rgba(1, 1, 1, 0.84)
            }

            Text {
                visible: root.queueReady && root.queueExpiresInSeconds > 0
                text: "Claim window: " + root.queueExpiresInSeconds + "s"
                font.family: "Montserrat"
                font.pixelSize: 13
                color: "#22c55e"
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Button {
                    Layout.fillWidth: true
                    text: root.queueReady ? "Launch Now" : "Browse Library"
                    onClicked: {
                        if (root.queueReady) {
                            root.claimQueuedGame()
                        } else {
                            root.queueOverlayExpanded = false
                        }
                    }
                }

                Button {
                    Layout.fillWidth: true
                    text: "Leave Queue"
                    onClicked: AirPCApiClient.leaveQueue()
                }
            }
        }
    }

    Button {
        id: queueBadge
        visible: root.queueInQueue && !root.queueOverlayExpanded
        z: 20
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 20
        anchors.bottomMargin: 22
        text: root.queueReady ? ("Ready: " + root.queueGameTitle)
                              : ("Queue #" + root.queuePosition + " - " + root.queueGameTitle)
        onClicked: root.queueOverlayExpanded = true
    }

    // ============================================================================
    // Funding choice dialog
    // ============================================================================

    Dialog {
        id: fundingChoiceDialog
        modal: true
        visible: root.showFundingChoiceModal
        anchors.centerIn: parent
        onRejected: {
            root.showFundingChoiceModal = false
            root.fundingChoiceContext = ""
        }

        title: "Choose Time Source"

        contentItem: ColumnLayout {
            width: Math.min(root.width * 0.9, 420)
            spacing: 10

            Text {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                font.family: "Montserrat"
                font.pixelSize: 13
                color: Qt.rgba(1, 1, 1, 0.88)
                text: root.fundingChoiceContext === "claim"
                    ? "Choose how to claim and launch " + root.queueGameTitle + "."
                    : "Choose how to launch " + root.pendingLaunchGameTitle + "."
            }

            ComboBox {
                id: subscriptionPicker
                visible: root.subscriptions && root.subscriptions.length > 1
                Layout.fillWidth: true
                model: root.subscriptions
                textRole: "label"
                onCurrentIndexChanged: {
                    if (currentIndex >= 0 && model[currentIndex] && model[currentIndex].subscription_instance_id) {
                        root.selectedSubscriptionInstanceId = model[currentIndex].subscription_instance_id
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Button {
                    Layout.fillWidth: true
                    enabled: root.hasSubscriptionPath
                    text: "Use Subscription"
                    onClicked: {
                        root.applyFundingChoice("subscription")
                        root.fundingChoiceContext = ""
                    }
                }

                Button {
                    Layout.fillWidth: true
                    enabled: root.hasVoucherPath
                    text: "Use Voucher"
                    onClicked: {
                        root.applyFundingChoice("voucher")
                        root.fundingChoiceContext = ""
                    }
                }
            }
        }
    }

    // ============================================================================
    // End Session Confirm Dialog  (matches .libraryModalPanel)
    // ============================================================================

    Dialog {
        id: endSessionDialog
        modal: true
        anchors.centerIn: parent
        padding: 0

        background: Rectangle {
            radius: 18
            color: Qt.rgba(20/255, 20/255, 30/255, 0.88)
            border.color: Qt.rgba(1, 1, 1, 0.16)
            border.width: 1

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.rgba(0, 0, 0, 0.42)
                shadowVerticalOffset: 18
                shadowBlur: 0.80
            }
        }

        ColumnLayout {
            width: Math.min(root.width * 0.92, 480)
            spacing: 14
            anchors.margins: 20

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    text: "End Active Session"
                    font.pixelSize: 20
                    font.weight: Font.Bold
                    font.family: "Montserrat"
                    color: root.textOnDark
                    Layout.fillWidth: true
                }

                // Close X button
                AbstractButton {
                    id: closeXBtn
                    implicitWidth: 32; implicitHeight: 32
                    contentItem: Text {
                        text: "✕"
                        font.pixelSize: 16
                        color: Qt.rgba(1, 1, 1, 0.70)
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        radius: 16
                        color: closeXBtn.hovered ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.08)
                        border.color: Qt.rgba(1, 1, 1, 0.24)
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    onClicked: endSessionDialog.close()
                }
            }

            // Message
            Text {
                text: "This will immediately stop your game on "
                    + (AirPCApiClient.activeSession ? AirPCApiClient.activeSession.computerName : "the host") + "."
                font.pixelSize: 14
                font.family: "Montserrat"
                color: Qt.rgba(1, 1, 1, 0.90)
                wrapMode: Text.Wrap
                Layout.fillWidth: true
                lineHeight: 1.45
            }

            // Warning pill
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: warnText.implicitHeight + 20
                radius: 10
                color: Qt.rgba(226/255, 99/255, 114/255, 0.14)
                border.color: Qt.rgba(226/255, 99/255, 114/255, 0.35)
                border.width: 1

                Text {
                    id: warnText
                    anchors.fill: parent
                    anchors.margins: 12
                    text: "Unsaved progress may be lost."
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    font.family: "Montserrat"
                    color: root.endRedText
                    wrapMode: Text.Wrap
                }
            }

            // Action row
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 6
                spacing: 10

                Item { Layout.fillWidth: true }

                // Cancel
                Button {
                    id: cancelBtn
                    implicitHeight: 38
                    contentItem: Text {
                        text: "Cancel"
                        font.pixelSize: 13; font.weight: Font.Bold; font.family: "Montserrat"
                        color: Qt.rgba(1, 1, 1, 0.98)
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        radius: 10; implicitWidth: 80
                        color: cancelBtn.hovered ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.14)
                        border.color: Qt.rgba(1, 1, 1, 0.34); border.width: 1
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    onClicked: endSessionDialog.close()
                }

                // Confirm
                Button {
                    id: confirmEndBtn
                    implicitHeight: 38
                    contentItem: Text {
                        text: "Yes, End Session"
                        font.pixelSize: 13; font.weight: Font.Bold; font.family: "Montserrat"
                        color: root.textOnDark
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        radius: 10; implicitWidth: 130
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.rgba(214/255, 69/255,  90/255, 0.78) }
                            GradientStop { position: 1.0; color: Qt.rgba(175/255, 47/255,  67/255, 0.78) }
                        }
                        border.color: Qt.rgba(226/255, 99/255, 114/255, 0.68); border.width: 1
                        scale: confirmEndBtn.pressed ? 0.97 : (confirmEndBtn.hovered ? 1.02 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 120 } }

                        layer.enabled: confirmEndBtn.hovered
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: Qt.rgba(175/255, 47/255, 67/255, 0.35)
                            shadowVerticalOffset: 6; shadowBlur: 0.60
                        }
                    }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    onClicked: {
                        endSessionDialog.close()
                        AirPCApiClient.endSession()
                    }
                }
            }
        }
    }

    // ============================================================================
    // Stream error dialog
    // ============================================================================
    Dialog {
        id: errorDialog
        modal: true
        anchors.centerIn: parent
        standardButtons: Dialog.Ok

        property string errorMessage: ""

        background: Rectangle {
            radius: 16
            color: Qt.rgba(20/255, 20/255, 30/255, 0.90)
            border.color: Qt.rgba(1, 1, 1, 0.16)
            border.width: 1
        }

        Label {
            text: errorDialog.errorMessage
            wrapMode: Text.Wrap
            width: Math.min(root.width * 0.85, 400)
            color: root.textOnDark
            font.family: "Montserrat"
            font.pixelSize: 14
        }
    }

    // ============================================================================
    // Game Model
    // ============================================================================
    AirPCGameModel { id: gameModelInstance }

    Connections {
        target: gameModelInstance

        function onGameLaunched(sessionId, streamHost, streamPort, httpsPort) {
            console.log("Stream launched:", sessionId, streamHost, streamPort)
            root.streamLaunched(sessionId, streamHost, streamPort, httpsPort)
        }

        function onLaunchFailed(error) {
            console.log("AirPCPublicGamesView: Launch failed -", error)

            var lower = (error || "").toLowerCase()
            if ((lower.indexOf("no computers") !== -1 || lower.indexOf("no available") !== -1)
                    && root.pendingLaunchGameUuid.length > 0) {
                AirPCApiClient.joinQueue(root.pendingLaunchGameUuid, root.pendingLaunchGameTitle, "auto", 0)
                return
            }

            errorDialog.errorMessage = error
            errorDialog.open()
        }

        function onStreamStarted() {
            console.log("AirPCPublicGamesView: Stream started")
        }

        function onStreamEnded(reason) {
            console.log("AirPCPublicGamesView: Stream ended -", reason)
        }

        function onStreamError(error) {
            console.log("AirPCPublicGamesView: Stream error -", error)
            errorDialog.errorMessage = error
            errorDialog.open()
        }

        function onSessionCreated(appName, session) {
            console.log("AirPCPublicGamesView: Session created for", appName)
            var component = Qt.createComponent("StreamSegue.qml")
            var segue = component.createObject(stackView, {
                "appName": appName,
                "session": session,
                "isResume": false
            })
            stackView.push(segue)
        }
    }

    Connections {
        target: AirPCApiClient

        function onQueueJoinSucceeded(position, gameTitle) {
            console.log("Queue joined:", position, gameTitle)
            root.queueOverlayExpanded = true
            AirPCApiClient.fetchQueueStatus()
        }

        function onQueueJoinFailed(error) {
            errorDialog.errorMessage = error
            errorDialog.open()
        }

        function onQueueClaimFailed(error) {
            errorDialog.errorMessage = error
            errorDialog.open()
        }

        function onQueueClaimSucceeded() {
            root.queueOverlayExpanded = false
            AirPCApiClient.fetchEntitlements()
            AirPCApiClient.fetchSharedPoolActiveSession()
        }

        function onQueueStateChanged() {
            if (root.queueReady) {
                root.queueOverlayExpanded = true
            }
        }

        function onEntitlementsChanged() {
            if (root.selectedSubscriptionInstanceId > 0 && root.subscriptions) {
                for (var i = 0; i < root.subscriptions.length; i++) {
                    if (root.subscriptions[i].subscription_instance_id === root.selectedSubscriptionInstanceId) {
                        return
                    }
                }
            }

            if (root.recommendedSubscriptionInstanceID > 0) {
                root.selectedSubscriptionInstanceId = root.recommendedSubscriptionInstanceID
            } else if (root.subscriptions && root.subscriptions.length > 0) {
                root.selectedSubscriptionInstanceId = root.subscriptions[0].subscription_instance_id
            } else {
                root.selectedSubscriptionInstanceId = 0
            }
        }
    }

    Timer {
        interval: 5000
        repeat: true
        running: root.queueInQueue
        onTriggered: AirPCApiClient.fetchQueueStatus()
    }

    Component.onCompleted: {
        if (AirPCApiClient.isLoggedIn) {
            gameModelInstance.refresh()
            AirPCApiClient.fetchEntitlements()
            AirPCApiClient.fetchQueueStatus()
            AirPCApiClient.fetchSharedPoolActiveSession()
        }
    }
}
