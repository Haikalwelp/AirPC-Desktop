pragma Singleton

import QtQuick 2.9

/**
 * AirPC Design System Theme
 * Centralized color palette and styling constants matching the web client design.
 */
QtObject {
    id: theme

    // ============================================================================
    // Primary Colors
    // ============================================================================

    // Primary brand color (burgundy/wine)
    readonly property color primary: "#8A1C5C"
    readonly property color primaryHover: Qt.rgba(138/255, 28/255, 92/255, 0.1)
    readonly property color primaryShadow: Qt.rgba(138/255, 28/255, 92/255, 0.25)

    // Text colors
    readonly property color textPrimary: "#454545"
    readonly property color textOnPrimary: "#FFFFFF"
    readonly property color textMuted: Qt.rgba(69/255, 69/255, 69/255, 0.7)

    // Danger/Logout color
    readonly property color danger: "#F94141"
    readonly property color dangerHover: "#d63636"
    readonly property color dangerBackground: Qt.rgba(249/255, 65/255, 65/255, 0.1)

    // ============================================================================
    // Header Gradient Colors
    // ============================================================================

    readonly property color gradientStart: "#DED1C6"
    readonly property color gradientMid: "#C49AAD"
    readonly property color gradientEnd: "#A77693"

    // Header border
    readonly property color headerBorder: Qt.rgba(1, 1, 1, 0.3)

    // ============================================================================
    // Spacing & Sizing
    // ============================================================================

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

    // ============================================================================
    // Font Family
    // ============================================================================

    readonly property string fontFamily: "Montserrat, sans-serif"

    // ============================================================================
    // Transitions
    // ============================================================================

    readonly property int transitionDuration: 150
}
