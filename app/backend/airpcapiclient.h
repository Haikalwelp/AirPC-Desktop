#pragma once

#include <QObject>
#include <QString>
#include <QList>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QJsonObject>
#include <QJsonArray>
#include <QSettings>

// ============================================================================
// API Data Models (matching Android ApiService.kt)
// ============================================================================

/**
 * Individual allocation and computer data from the API.
 * Matches AllocationApiResponse in Android.
 */
class AirPCAllocation {
public:
    int allocationId = 0;
    int accountId = 0;
    QString username;
    QString computerUuid;
    QString computerName;
    QString hostname;
    int port = 47989;
    QString status;
    QString lastSeen;
    QString allocationDate;
    QString expiryDate;
    bool isActive = false;
    bool isExpired = false;
    QString notes;
    int playtimeSeconds = 0;
    int remainingSeconds = 0;

    static AirPCAllocation fromJson(const QJsonObject& json);
    QJsonObject toJson() const;
};
Q_DECLARE_METATYPE(AirPCAllocation)

/**
 * Public app/game data from the API.
 * Matches PublicApp in Android.
 */
class AirPCPublicApp {
public:
    QString id;
    QString title;
    QString uuid;
    bool hdrSupported = false;
    QString computerName;
    QString computerUuid;
    QString hostname;
    int port = 47989;

    static AirPCPublicApp fromJson(const QJsonObject& json, const AirPCAllocation& allocation);
    QString getImageUrl(const QString& authToken, const QString& apiBaseUrl) const;
};
Q_DECLARE_METATYPE(AirPCPublicApp)

/**
 * Stream launch request payload.
 * Matches StreamLaunchRequest in Android.
 */
class AirPCStreamLaunchRequest {
public:
    QString computerUuid;
    QString appId;
    QString appUuid;
    QString deviceId;

    QJsonObject toJson() const;
};

/**
 * Stream launch response from API.
 * Matches StreamLaunchResponse in Android.
 */
class AirPCStreamLaunchResponse {
public:
    bool success = false;
    QString message;
    QString sessionId;
    QString sessionToken;
    int allocationId = 0;
    int playtimeSeconds = 0;
    int remainingSeconds = 0;
    QString streamHost;
    int streamPort = 0;
    int streamHttpsPort = 0;
    QString computerUuid;
    QString computerName;
    
    // App information (needed for resume - set from AirPCActiveSession or launch request)
    QString appId;
    QString appName;

    static AirPCStreamLaunchResponse fromJson(const QJsonObject& json);
};
Q_DECLARE_METATYPE(AirPCStreamLaunchResponse)

/**
 * Active session entity for persistence.
 * Matches ActiveSessionEntity in Android.
 */
class AirPCActiveSession {
public:
    QString sessionId;
    int allocationId = 0;
    int accountId = 0;
    QString computerUuid;
    QString computerName;
    QString hostname;
    int port = 0;
    int httpsPort = 0;
    QString appId;
    QString appName;
    QString sessionToken;
    qint64 startedAt = 0;
    int playtimeSeconds = 0;
    qint64 lastConnected = 0;

    bool isValid() const { return !sessionId.isEmpty(); }
    static AirPCActiveSession fromJson(const QJsonObject& json);
    QJsonObject toJson() const;
};
Q_DECLARE_METATYPE(AirPCActiveSession)

/**
 * User profile from API.
 */
class AirPCUserProfile {
public:
    int accountId = 0;
    QString username;
    QString email;
    int playtimeSeconds = 0;
    int claimCount = 0;

    static AirPCUserProfile fromJson(const QJsonObject& json);
};
Q_DECLARE_METATYPE(AirPCUserProfile)

// ============================================================================
// AirPC API Client
// ============================================================================

/**
 * HTTP client for AirPC cloud API.
 * Matches ApiClient.kt + ApiService.kt in Android.
 * 
 * Thread-safe singleton that handles:
 * - Authentication (login, token management)
 * - Fetching allocations
 * - Fetching apps via Go API proxy
 * - Launching/ending streams
 */
class AirPCApiClient : public QObject
{
    Q_OBJECT

    // Expose properties to QML
    Q_PROPERTY(bool isLoggedIn READ isLoggedIn NOTIFY loginStateChanged)
    Q_PROPERTY(QString username READ username NOTIFY loginStateChanged)
    Q_PROPERTY(bool isLoading READ isLoading NOTIFY loadingChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY errorOccurred)

public:
    static AirPCApiClient* get();

    // Authentication
    Q_INVOKABLE void login(const QString& username, const QString& password, bool rememberMe);
    Q_INVOKABLE void logout();
    bool isLoggedIn() const;
    QString username() const;
    QString authToken() const;

    // Loading state
    bool isLoading() const { return m_isLoading; }
    QString errorMessage() const { return m_errorMessage; }

    // Allocations
    Q_INVOKABLE void fetchAllocations();
    QList<AirPCAllocation> allocations() const { return m_allocations; }
    AirPCAllocation* getAllocationForComputer(const QString& computerUuid);

    // Apps (via Go API proxy)
    Q_INVOKABLE void fetchAppsForAllocation(const AirPCAllocation& allocation);
    Q_INVOKABLE void fetchAllApps();
    QList<AirPCPublicApp> apps() const { return m_apps; }

    // Stream management
    Q_INVOKABLE void launchStream(const QString& computerUuid, const QString& appId, const QString& appUuid);
    Q_INVOKABLE void endSession();
    Q_INVOKABLE void resumeSession();

    // Session management
    AirPCActiveSession activeSession() const { return m_activeSession; }
    bool hasActiveSession() const { return m_activeSession.isValid(); }
    Q_INVOKABLE void saveActiveSession(const AirPCActiveSession& session);
    Q_INVOKABLE void clearActiveSession();
    Q_INVOKABLE void loadActiveSession();

    // Profile
    Q_INVOKABLE void fetchProfile();

    // Configuration
    QString apiBaseUrl() const { return m_apiBaseUrl; }
    void setApiBaseUrl(const QString& url);
    QString getDeviceId();  // Device ID for session management

signals:
    // Authentication signals
    void loginStateChanged();
    void loginSuccess();
    void loginFailed(const QString& error);
    void logoutCompleted();

    // Data loading signals
    void loadingChanged();
    void errorOccurred(const QString& error);
    void allocationsLoaded(const QList<AirPCAllocation>& allocations);
    void appsLoaded(const QList<AirPCPublicApp>& apps);
    void appsLoadProgress(int loaded, int total);
    void profileLoaded(const AirPCUserProfile& profile);

    // Stream signals
    void streamLaunched(const AirPCStreamLaunchResponse& response);
    void streamLaunchFailed(const QString& error);
    void sessionEnded();
    void activeSessionChanged();

private:
    explicit AirPCApiClient(QObject* parent = nullptr);
    ~AirPCApiClient() override = default;

    // Network helpers
    QNetworkRequest createRequest(const QString& endpoint, bool authenticated = true);
    void handleNetworkError(QNetworkReply* reply);
    
    // Host control (matching Android's quitAppOnHost)
    void quitAppOnHost();

    // Credential storage
    void saveCredentials(const QString& token, const QString& username, bool rememberMe);
    void loadCredentials();
    void clearCredentials();
    bool isTokenExpired(const QString& token) const;
    qint64 extractTokenExpiry(const QString& token) const;

    // Members
    QNetworkAccessManager m_nam;
    QString m_apiBaseUrl;
    QString m_authToken;
    QString m_username;
    bool m_isLoading = false;
    QString m_errorMessage;
    QString m_deviceId;

    // Data
    QList<AirPCAllocation> m_allocations;
    QList<AirPCPublicApp> m_apps;
    AirPCActiveSession m_activeSession;

    // Settings
    QSettings m_settings;

    // Constants
    static constexpr int CONNECTION_TIMEOUT_MS = 15000;
    static constexpr int READ_TIMEOUT_MS = 15000;
};
