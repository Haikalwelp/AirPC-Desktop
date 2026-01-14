pragma Singleton

import QtQuick
import QtQuick.Controls

import AirPCApiClient 1.0

QtObject {
    id: router

    // ============================================================================
    // Properties
    // ============================================================================

    // Reference to the StackView, must be set from main.qml
    property var stackView: null

    // Current route name (e.g., "login", "games", "settings")
    property string currentRoute: ""

    // Route saved when auth guard redirects to login
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
        "games": {
            url: "qrc:/gui/AirPCPublicGamesView.qml",
            protected: true,
            objectName: "Game Library"
        },
        "settings": {
            url: "qrc:/gui/SettingsView.qml",
            protected: true,
            objectName: "Settings"
        },
        "profile": {
            url: "qrc:/gui/ProfileView.qml",
            protected: true,
            objectName: "Profile"
        },
        "playtime": {
            url: "qrc:/gui/PlaytimeView.qml",
            protected: true,
            objectName: "Playtime"
        }
    })

    // ============================================================================
    // Navigation Functions
    // ============================================================================

    /**
     * Push a new route onto the stack.
     * If the route is protected and user is not logged in, redirects to login.
     * @param routeName - The name of the route to navigate to
     */
    function push(routeName) {
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
            pendingRoute = routeName
            navigateToRoute("login", "push")
            return
        }

        navigateToRoute(routeName, "push")
    }

    /**
     * Replace the current route with a new one.
     * If the route is protected and user is not logged in, redirects to login.
     * @param routeName - The name of the route to navigate to
     */
    function replace(routeName) {
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
            pendingRoute = routeName
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

        var targetRoute = pendingRoute !== "" ? pendingRoute : "games"
        console.log("[Router] Navigating to:", targetRoute)

        pendingRoute = ""
        replace(targetRoute)
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

        var targetRoute = initialRoute

        // Determine default route based on auth state
        if (!targetRoute || targetRoute === "") {
            targetRoute = isLoggedIn ? "games" : "login"
            console.log("[Router] No initial route specified, defaulting to:", targetRoute)
        }

        // Validate route exists
        if (!routes[targetRoute]) {
            console.error("[Router] Error: Unknown initial route:", targetRoute)
            targetRoute = isLoggedIn ? "games" : "login"
            console.log("[Router] Falling back to:", targetRoute)
        }

        // Check auth guard for initial route
        var routeConfig = routes[targetRoute]
        if (routeConfig.protected && !isLoggedIn) {
            console.log("[Router] Initial route is protected but user not logged in")
            pendingRoute = targetRoute
            targetRoute = "login"
        }

        // Navigate to initial route
        routeConfig = routes[targetRoute]
        stackView.push(routeConfig.url)
        currentRoute = targetRoute

        console.log("[Router] Initialized with route:", currentRoute)
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

        // No match found - might be a non-router managed view
        console.log("[Router] No route match found for objectName:", currentObjectName)
        currentRoute = ""
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
