pragma Singleton

import QtQuick

import AirPCApiClient 1.0

QtObject {
    id: router

    // ============================================================================
    // Properties
    // ============================================================================

    // Reference to the StackView, must be set from main.qml
    property var stackView: null

    // Current stack route ("login" | "shell" | "")
    property string currentRoute: ""

    // Current active top-level tab
    property string currentTab: "games"

    // Tab saved when auth guard redirects to login
    property string pendingRoute: ""

    // Auth state bound to AirPCApiClient
    property bool isLoggedIn: AirPCApiClient.isLoggedIn

    // ============================================================================
    // Route Definitions
    // ============================================================================

    readonly property var routes: ({
        "login": {
            url: "qrc:/gui/AirPCLoginView.qml",
            protected: false,
            objectName: "LoginView"
        },
        "shell": {
            url: "qrc:/gui/AirPCShellView.qml",
            protected: true,
            objectName: "Shell"
        },
        "forgot-password": {
            url: "qrc:/gui/AirPCForgotPasswordView.qml",
            protected: false,
            objectName: "ForgotPasswordView"
        },
        "signup": {
            url: "qrc:/gui/AirPCSignupView.qml",
            protected: false,
            objectName: "SignupView"
        }
    })

    readonly property var tabs: (["games", "profile", "settings", "playtime"])

    // ============================================================================
    // Navigation Functions
    // ============================================================================

    function isTabRoute(routeName) {
        return tabs.indexOf(routeName) !== -1
    }

    /**
     * Switch between top-level pages via the navbar.
     * This keeps tab pages alive and avoids growing StackView depth.
     */
    function switchTab(tabName) {
        console.log("[Router] switchTab()", tabName)

        if (!stackView) {
            console.error("[Router] Error: stackView is not set")
            return
        }

        if (!isTabRoute(tabName)) {
            console.error("[Router] Error: Unknown tab:", tabName)
            return
        }

        // Auth guard
        if (!isLoggedIn) {
            pendingRoute = tabName
            navigateToRoute("login", stackView.depth > 0 ? "replace" : "push")
            return
        }

        var shellConfig = routes["shell"]

        // If Shell is already the current root view, just switch tabs.
        if (stackView.currentItem && stackView.currentItem.objectName === shellConfig.objectName) {
            stackView.currentItem.currentTab = tabName
        } else {
            // Put Shell at the root of the stack (replace login / any other root).
            if (stackView.depth === 0) {
                stackView.push(shellConfig.url, { "initialTab": tabName, "currentTab": tabName })
            } else {
                stackView.replace(shellConfig.url, { "initialTab": tabName, "currentTab": tabName })
            }
        }

        currentRoute = "shell"
        currentTab = tabName
    }

    /**
     * Push a route onto the stack (used for non-tab, nested flows).
     */
    function push(routeName) {
        if (isTabRoute(routeName)) {
            switchTab(routeName)
            return
        }

        console.log("[Router] push() called with route:", routeName)

        if (!stackView) {
            console.error("[Router] Error: stackView is not set")
            return
        }

        var routeConfig = routes[routeName]
        if (!routeConfig) {
            console.error("[Router] Error: Unknown route:", routeName)
            return
        }

        // Auth guard check
        if (routeConfig.protected && !isLoggedIn) {
            console.log("[Router] Route is protected and user is not logged in, redirecting to login")
            pendingRoute = "games"
            navigateToRoute("login", "push")
            return
        }

        // If user is already logged in and tries to navigate to a public-only auth route, redirect to games
        if (!routeConfig.protected && isLoggedIn && (routeName === "forgot-password" || routeName === "signup")) {
            console.log("[Router] Already logged in, redirecting to games instead of:", routeName)
            switchTab("games")
            return
        }

        navigateToRoute(routeName, "push")
    }

    /**
     * Replace the current route (used for login/logout transitions).
     */
    function replace(routeName) {
        if (isTabRoute(routeName)) {
            switchTab(routeName)
            return
        }

        console.log("[Router] replace() called with route:", routeName)

        if (!stackView) {
            console.error("[Router] Error: stackView is not set")
            return
        }

        var routeConfig = routes[routeName]
        if (!routeConfig) {
            console.error("[Router] Error: Unknown route:", routeName)
            return
        }

        // Auth guard check
        if (routeConfig.protected && !isLoggedIn) {
            console.log("[Router] Route is protected and user is not logged in, redirecting to login")
            pendingRoute = "games"
            navigateToRoute("login", "replace")
            return
        }

        navigateToRoute(routeName, "replace")
    }

    /**
     * Go back to the previous route if possible.
     */
    function back() {
        console.log("[Router] back() called")

        if (!stackView) {
            console.error("[Router] Error: stackView is not set")
            return
        }

        if (stackView.depth > 1) {
            stackView.pop()
            updateCurrentRouteFromStack()
            console.log("[Router] Popped stack, current route:", currentRoute)
        } else {
            console.log("[Router] Cannot go back, already at root")
        }
    }

    /**
     * Called after successful login. Navigates to pending route or default (games).
     */
    function onLoginSuccess() {
        console.log("[Router] onLoginSuccess() called")

        var targetTab = pendingRoute !== "" ? pendingRoute : "games"
        console.log("[Router] Navigating to tab:", targetTab)

        pendingRoute = ""
        switchTab(targetTab)
    }

    /**
     * Called on logout. Clears the stack and navigates to login.
     */
    function onLogout() {
        console.log("[Router] onLogout() called")

        if (!stackView) {
            console.error("[Router] Error: stackView is not set")
            return
        }

        pendingRoute = ""

        // Clear the stack and go to login
        stackView.clear()
        var routeConfig = routes["login"]
        stackView.push(routeConfig.url)
        currentRoute = "login"

        console.log("[Router] Cleared stack and navigated to login")
    }

    /**
     * Initialize the router with an initial route.
     * Defaults to "games" if logged in, "login" if not.
     * @param initialRoute - Optional initial route name
     */
    function init(initialRoute) {
        console.log("[Router] init() called with initialRoute:", initialRoute)

        if (!stackView) {
            console.error("[Router] Error: stackView is not set")
            return
        }

        // If a tab name is requested, switch to it.
        if (initialRoute && initialRoute !== "" && isTabRoute(initialRoute)) {
            switchTab(initialRoute)
            return
        }

        // Default startup behavior
        if (!isLoggedIn) {
            navigateToRoute("login", "push")
            return
        }

        // Logged in: start in Shell, default tab = games
        switchTab("games")
    }

    /**
     * Helper to map the current stack item's objectName back to a route name.
     */
    function updateCurrentRouteFromStack() {
        if (!stackView || !stackView.currentItem) {
            currentRoute = ""
            return
        }

        var currentObjectName = stackView.currentItem.objectName
        console.log("[Router] updateCurrentRouteFromStack(), objectName:", currentObjectName)

        // Find route by objectName
        for (var routeName in routes) {
            if (routes[routeName].objectName === currentObjectName) {
                currentRoute = routeName
                console.log("[Router] Matched route:", routeName)
                return
            }
        }

        // No match found - might be a nested/non-router view. Keep currentRoute/tab.
        console.log("[Router] No route match found for objectName:", currentObjectName)
    }

    // ============================================================================
    // Internal Helpers
    // ============================================================================

    /**
     * Internal function to perform the actual navigation.
     * @param routeName - The route name to navigate to
     * @param method - "push" or "replace"
     */
    function navigateToRoute(routeName, method) {
        var routeConfig = routes[routeName]

        console.log("[Router] navigateToRoute():", routeName, "method:", method, "url:", routeConfig.url)

        if (method === "push") {
            stackView.push(routeConfig.url)
        } else if (method === "replace") {
            stackView.replace(routeConfig.url)
        }

        currentRoute = routeName
        console.log("[Router] Navigation complete, currentRoute:", currentRoute)
    }
}
