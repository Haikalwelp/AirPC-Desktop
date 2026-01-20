pragma Singleton

import QtQuick 2.9

/**
 * AirPC Design System Theme
 * Centralized color palette and styling constants matching the web client design.
 *
 * Web CSS Reference:
 *   - Gradient: linear-gradient(135deg, #DED1C6 0%, #A77693 33%, #174871 66%, #0F2D4D 100%)
 *   - Glass Card: rgba(255,255,255,0.45), blur(12px), border 1.5px rgba(255,255,255,0.25)
 *   - Primary: #8A1C5C
 *   - Text on glass: #454545
 */
QtObject {
    id: theme

    // ============================================================================
    // Primary Colors
    // ============================================================================

    // Primary brand color (burgundy/wine)
    readonly property color primary: "#8A1C5C"
    readonly property color primaryHover: Qt.lighter("#8A1C5C", 1.15)
    readonly property color primaryPressed: Qt.darker("#8A1C5C", 1.1)
    readonly property color primaryShadow: Qt.rgba(138/255, 28/255, 92/255, 0.25)

    // Text colors - for glass cards (light background)
    readonly property color textPrimary: "#454545"
    readonly property color textOnPrimary: "#FFFFFF"
    readonly property color textMuted: Qt.rgba(69/255, 69/255, 69/255, 0.7)
    readonly property color textSecondary: Qt.rgba(69/255, 69/255, 69/255, 0.6)

    // Text colors - for page headers (on gradient)
    readonly property color textOnGradient: "#FFFFFF"
    readonly property color textOnGradientMuted: Qt.rgba(255, 255, 255, 0.8)

    // Danger/Logout color
    readonly property color danger: "#F94141"
    readonly property color dangerHover: "#d63636"
    readonly property color dangerBackground: Qt.rgba(249/255, 65/255, 65/255, 0.1)

    // Success color
    readonly property color success: "#22c55e"

    // ============================================================================
    // AirPC Background Gradient (4-stop diagonal gradient)
    // ============================================================================

    // Gradient colors in order (135deg: top-left to bottom-right)
    readonly property color gradientStop1: "#DED1C6"  // 0% - cream/beige
    readonly property color gradientStop2: "#A77693"  // 33% - dusty rose
    readonly property color gradientStop3: "#174871"  // 66% - navy blue
    readonly property color gradientStop4: "#0F2D4D"  // 100% - dark navy

    // Header gradient (lighter portion)
    readonly property color gradientStart: "#DED1C6"
    readonly property color gradientMid: "#C49AAD"
    readonly property color gradientEnd: "#A77693"

    // Header border
    readonly property color headerBorder: Qt.rgba(1, 1, 1, 0.3)

    // ============================================================================
    // Glass Card (Glassmorphism)
    // ============================================================================

    // Main glass card background (semi-transparent white)
    readonly property color glassBackground: Qt.rgba(255/255, 255/255, 255/255, 0.45)
    readonly property color glassBorder: Qt.rgba(255/255, 255/255, 255/255, 0.25)
    readonly property real glassBorderWidth: 1.5
    readonly property int glassRadius: 16
    readonly property int glassPadding: 28

    // Inner glass elements (for stat boxes, summary boxes)
    readonly property color glassInner: Qt.rgba(255/255, 255/255, 255/255, 0.2)
    readonly property color glassInnerBorder: Qt.rgba(255/255, 255/255, 255/255, 0.15)
    readonly property int glassInnerRadius: 12

    // ============================================================================
    // Buttons
    // ============================================================================

    // Primary button
    readonly property int buttonHeight: 52
    readonly property int buttonRadius: 26  // pill shape
    readonly property int buttonFontSize: 16

    // SKU card (selectable package)
    readonly property color skuBackground: Qt.rgba(255/255, 255/255, 255/255, 0.25)
    readonly property color skuBorder: Qt.rgba(69/255, 69/255, 69/255, 0.15)
    readonly property color skuBorderSelected: "#8A1C5C"
    readonly property int skuRadius: 16

    // ============================================================================
    // Input Fields
    // ============================================================================

    readonly property color inputBackground: Qt.rgba(255/255, 255/255, 255/255, 0.3)
    readonly property color inputBackgroundFocus: Qt.rgba(255/255, 255/255, 255/255, 0.5)
    readonly property color inputBorder: Qt.rgba(69/255, 69/255, 69/255, 0.15)
    readonly property color inputBorderFocus: "#8A1C5C"
    readonly property int inputHeight: 52
    readonly property int inputRadius: 12

    // ============================================================================
    // Spacing & Sizing
    // ============================================================================

    // Content area
    readonly property int contentMaxWidth: 900
    readonly property int contentPaddingH: 32
    readonly property int contentPaddingV: 40

    // Page header
    readonly property int pageTitleSize: 32
    readonly property int pageSubtitleSize: 16
    readonly property int pageHeaderMargin: 32

    // Card title
    readonly property int cardTitleSize: 18

    // Playtime display
    readonly property int playtimeValueSize: 48

    // Navigation button
    readonly property int navButtonRadius: 22
    readonly property int navButtonPaddingH: 20
    readonly property int navButtonPaddingV: 10
    readonly property int navButtonFontSize: 14

    // Header
    readonly property int headerHeight: 60
    readonly property int headerPadding: 16

    // Logo
    readonly property int logoFontSize: 24

    // User section
    readonly property int usernameFontSize: 14

    // Avatar
    readonly property int avatarSize: 64
    readonly property int avatarFontSize: 24

    // ============================================================================
    // Font Family
    // ============================================================================

    // Primary font with fallbacks for cross-platform compatibility
    // Montserrat -> Segoe UI (Windows) -> SF Pro (macOS) -> system default
    readonly property string fontFamily: "Montserrat"
    readonly property string fontFamilyFallback: "Segoe UI"  // Windows fallback

    // ============================================================================
    // Transitions
    // ============================================================================

    readonly property int transitionDuration: 150
    readonly property int transitionDurationSlow: 200
}
