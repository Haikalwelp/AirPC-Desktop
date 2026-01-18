#include "airpcapiclient.h"
#include "nvhttp.h"
#include "nvaddress.h"

#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QNetworkRequest>
#include <QUrlQuery>
#include <QUuid>
#include <QCoreApplication>
#include <QSysInfo>

// ============================================================================
// AirPCAllocation Implementation
// ============================================================================

AirPCAllocation AirPCAllocation::fromJson(const QJsonObject& json)
{
    AirPCAllocation allocation;
    allocation.allocationId = json["allocation_id"].toInt();
    allocation.accountId = json["account_id"].toInt();
    allocation.username = json["username"].toString();
    allocation.computerUuid = json["computer_uuid"].toString();
    allocation.computerName = json["computer_name"].toString();
    allocation.hostname = json["hostname"].toString();
    allocation.port = json["port"].toInt(47989);
    allocation.status = json["status"].toString();
    allocation.lastSeen = json["last_seen"].toString();
    allocation.allocationDate = json["allocation_date"].toString();
    allocation.expiryDate = json["expiry_date"].toString();
    allocation.isActive = json["is_active"].toBool();
    allocation.isExpired = json["is_expired"].toBool();
    allocation.notes = json["notes"].toString();
    allocation.playtimeSeconds = json["playtime_seconds"].toInt();
    allocation.remainingSeconds = json["remaining_seconds"].toInt();
    return allocation;
}

QJsonObject AirPCAllocation::toJson() const
{
    QJsonObject json;
    json["allocation_id"] = allocationId;
    json["account_id"] = accountId;
    json["username"] = username;
    json["computer_uuid"] = computerUuid;
    json["computer_name"] = computerName;
    json["hostname"] = hostname;
    json["port"] = port;
    json["status"] = status;
    json["last_seen"] = lastSeen;
    json["allocation_date"] = allocationDate;
    json["expiry_date"] = expiryDate;
    json["is_active"] = isActive;
    json["is_expired"] = isExpired;
    json["notes"] = notes;
    json["playtime_seconds"] = playtimeSeconds;
    json["remaining_seconds"] = remainingSeconds;
    return json;
}

// ============================================================================
// AirPCPublicApp Implementation
// ============================================================================

AirPCPublicApp AirPCPublicApp::fromJson(const QJsonObject& json, const AirPCAllocation& allocation)
{
    AirPCPublicApp app;
    app.id = QString::number(json["id"].toInt());
    app.title = json["title"].toString();
    app.uuid = json["uuid"].toString();
    app.hdrSupported = json["hdr_supported"].toBool();
    app.computerName = allocation.computerName;
    app.computerUuid = allocation.computerUuid;
    app.hostname = allocation.hostname;
    app.port = allocation.port;
    return app;
}

QString AirPCPublicApp::getImageUrl(const QString& authToken, const QString& apiBaseUrl) const
{
    // Image URL via API proxy: https://api.airpc.io/api/v1/computer/{uuid}/apps/{id}/icon?token=...
    return QString("%1/api/v1/computer/%2/apps/%3/icon?token=%4")
        .arg(apiBaseUrl)
        .arg(computerUuid)
        .arg(id)
        .arg(authToken);
}

// ============================================================================
// AirPCStreamLaunchRequest Implementation
// ============================================================================

QJsonObject AirPCStreamLaunchRequest::toJson() const
{
    QJsonObject json;
    json["computer_uuid"] = computerUuid;
    json["app_id"] = appId;
    if (!appUuid.isEmpty()) {
        json["app_uuid"] = appUuid;
    }
    if (!deviceId.isEmpty()) {
        json["device_id"] = deviceId;
    }
    return json;
}

// ============================================================================
// AirPCStreamLaunchResponse Implementation
// ============================================================================

AirPCStreamLaunchResponse AirPCStreamLaunchResponse::fromJson(const QJsonObject& json)
{
    AirPCStreamLaunchResponse response;
    response.success = json["success"].toBool();
    response.message = json["message"].toString();
    response.sessionId = json["session_id"].toString();
    response.sessionToken = json["session_token"].toString();
    response.allocationId = json["allocation_id"].toInt();
    response.playtimeSeconds = json["playtime_seconds"].toInt();
    response.remainingSeconds = json["remaining_seconds"].toInt();
    response.streamHost = json["stream_host"].toString();
    response.streamPort = json["stream_port"].toInt();
    response.streamHttpsPort = json["stream_https_port"].toInt();
    response.computerUuid = json["computer_uuid"].toString();
    response.computerName = json["computer_name"].toString();
    return response;
}

// ============================================================================
// AirPCActiveSession Implementation
// ============================================================================

AirPCActiveSession AirPCActiveSession::fromJson(const QJsonObject& json)
{
    AirPCActiveSession session;
    session.sessionId = json["session_id"].toString();
    session.allocationId = json["allocation_id"].toInt();
    session.accountId = json["account_id"].toInt();
    session.computerUuid = json["computer_uuid"].toString();
    session.computerName = json["computer_name"].toString();
    session.hostname = json["hostname"].toString();
    session.port = json["port"].toInt();
    session.httpsPort = json["https_port"].toInt();
    session.appId = json["app_id"].toString();
    session.appName = json["app_name"].toString();
    session.sessionToken = json["session_token"].toString();
    session.startedAt = json["started_at"].toVariant().toLongLong();
    session.playtimeSeconds = json["playtime_seconds"].toInt();
    session.lastConnected = json["last_connected"].toVariant().toLongLong();
    return session;
}

QJsonObject AirPCActiveSession::toJson() const
{
    QJsonObject json;
    json["session_id"] = sessionId;
    json["allocation_id"] = allocationId;
    json["account_id"] = accountId;
    json["computer_uuid"] = computerUuid;
    json["computer_name"] = computerName;
    json["hostname"] = hostname;
    json["port"] = port;
    json["https_port"] = httpsPort;
    json["app_id"] = appId;
    json["app_name"] = appName;
    json["session_token"] = sessionToken;
    json["started_at"] = startedAt;
    json["playtime_seconds"] = playtimeSeconds;
    json["last_connected"] = lastConnected;
    return json;
}

// ============================================================================
// AirPCUserProfile Implementation
// ============================================================================

AirPCUserProfile AirPCUserProfile::fromJson(const QJsonObject& json)
{
    AirPCUserProfile profile;
    profile.accountId = json["account_id"].toInt();
    profile.username = json["username"].toString();
    profile.email = json["email"].toString();
    profile.playtimeSeconds = json["playtime_seconds"].toInt();
    profile.claimCount = json["claim_count"].toInt();
    return profile;
}

// ============================================================================
// AirPCHeartbeatResponse Implementation
// ============================================================================

AirPCHeartbeatResponse AirPCHeartbeatResponse::fromJson(const QJsonObject& json)
{
    AirPCHeartbeatResponse response;
    response.valid = json["valid"].toBool(false);
    response.remainingSeconds = json["remaining_seconds"].toInt(0);
    response.remainingPlaytime = json["remaining_playtime"].toInt(0);
    response.message = json["message"].toString();
    response.idleWarning = json["idle_warning"].toBool(false);
    response.idleSeconds = json["idle_seconds"].toInt(0);
    return response;
}

// ============================================================================
// AirPCClaimResponse Implementation
// ============================================================================

AirPCClaimResponse AirPCClaimResponse::fromJson(const QJsonObject& json)
{
    AirPCClaimResponse response;
    response.success = json["success"].toBool(false);
    response.playtimeGranted = json["playtime_granted"].toInt(0);
    response.totalPlaytime = json["total_playtime"].toInt(0);
    response.message = json["message"].toString();
    return response;
}

// ============================================================================
// AirPCOrderClaim Implementation
// ============================================================================

AirPCOrderClaim AirPCOrderClaim::fromJson(const QJsonObject& json)
{
    AirPCOrderClaim claim;
    claim.claimId = json["claim_id"].toInt();
    claim.orderSn = json["order_sn"].toString();
    claim.playtimeGranted = json["playtime_granted"].toInt();
    claim.claimedAt = json["claimed_at"].toString();
    return claim;
}

// ============================================================================
// AirPCApiClient Implementation
// ============================================================================

AirPCApiClient* AirPCApiClient::get()
{
    static AirPCApiClient* instance = new AirPCApiClient();
    return instance;
}

AirPCApiClient::AirPCApiClient(QObject* parent)
    : QObject(parent)
    , m_nam(this)
    , m_apiBaseUrl("https://api.airpc.co") // Default API URL
{
    // Load saved credentials on startup
    loadCredentials();
    loadActiveSession();

    qInfo() << "AirPCApiClient: Initialized with API URL:" << m_apiBaseUrl;
}

// ============================================================================
// Authentication
// ============================================================================

void AirPCApiClient::login(const QString& username, const QString& password, bool rememberMe)
{
    qInfo() << "AirPCApiClient: Attempting login for user:" << username;

    m_isLoading = true;
    emit loadingChanged();

    QUrl url(m_apiBaseUrl + "/api/v1/auth/login");
    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    request.setTransferTimeout(CONNECTION_TIMEOUT_MS);

    QJsonObject body;
    body["username"] = username;
    body["password"] = password;

    QNetworkReply* reply = m_nam.post(request, QJsonDocument(body).toJson());
    connect(reply, &QNetworkReply::finished, this, [this, reply, username, rememberMe]() {
        m_isLoading = false;
        emit loadingChanged();
        reply->deleteLater();

        if (reply->error() != QNetworkReply::NoError) {
            QString error = reply->errorString();
            qWarning() << "AirPCApiClient: Login failed:" << error;

            // Try to parse error response
            QByteArray data = reply->readAll();
            QJsonDocument doc = QJsonDocument::fromJson(data);
            if (doc.isObject() && doc.object().contains("message")) {
                error = doc.object()["message"].toString();
            }

            m_errorMessage = error;
            emit errorOccurred(error);
            emit loginFailed(error);
            return;
        }

        QByteArray data = reply->readAll();
        QJsonDocument doc = QJsonDocument::fromJson(data);
        QJsonObject json = doc.object();

        if (!json["success"].toBool()) {
            QString error = json["message"].toString("Login failed");
            qWarning() << "AirPCApiClient: Login rejected:" << error;
            m_errorMessage = error;
            emit errorOccurred(error);
            emit loginFailed(error);
            return;
        }

        QString token = json["token"].toString();
        if (token.isEmpty()) {
            QString error = "No token received from server";
            qWarning() << "AirPCApiClient:" << error;
            m_errorMessage = error;
            emit errorOccurred(error);
            emit loginFailed(error);
            return;
        }

        m_authToken = token;
        m_username = username;
        saveCredentials(token, username, rememberMe);

        qInfo() << "AirPCApiClient: Login successful for:" << username;
        emit loginStateChanged();
        emit loginSuccess();
    });
}

void AirPCApiClient::logout()
{
    qInfo() << "AirPCApiClient: Logging out user:" << m_username;

    // End any active session first
    if (hasActiveSession()) {
        endSession();
    }

    clearCredentials();
    m_authToken.clear();
    m_username.clear();
    m_allocations.clear();
    m_apps.clear();
    clearActiveSession();

    emit loginStateChanged();
    emit logoutCompleted();
}

bool AirPCApiClient::isLoggedIn() const
{
    return !m_authToken.isEmpty() && !isTokenExpired(m_authToken);
}

QString AirPCApiClient::username() const
{
    return m_username;
}

QString AirPCApiClient::authToken() const
{
    return m_authToken;
}

// ============================================================================
// Allocations
// ============================================================================

void AirPCApiClient::fetchAllocations()
{
    if (!isLoggedIn()) {
        qWarning() << "AirPCApiClient: Cannot fetch allocations - not logged in";
        emit errorOccurred("Not logged in");
        return;
    }

    qInfo() << "AirPCApiClient: Fetching allocations...";

    m_isLoading = true;
    emit loadingChanged();

    QUrl url(m_apiBaseUrl + "/api/v1/allocations/my");
    QUrlQuery query;
    query.addQueryItem("active_only", "true");
    url.setQuery(query);

    QNetworkRequest request = createRequest(url.toString());
    QNetworkReply* reply = m_nam.get(request);

    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        m_isLoading = false;
        emit loadingChanged();
        reply->deleteLater();

        if (reply->error() != QNetworkReply::NoError) {
            handleNetworkError(reply);
            return;
        }

        QByteArray data = reply->readAll();
        QJsonDocument doc = QJsonDocument::fromJson(data);
        QJsonObject json = doc.object();

        if (!json["success"].toBool()) {
            QString error = json["message"].toString("Failed to fetch allocations");
            qWarning() << "AirPCApiClient:" << error;
            m_errorMessage = error;
            emit errorOccurred(error);
            return;
        }

        m_allocations.clear();
        QJsonArray allocationsArray = json["allocations"].toArray();
        for (const QJsonValue& value : allocationsArray) {
            m_allocations.append(AirPCAllocation::fromJson(value.toObject()));
        }

        qInfo() << "AirPCApiClient: Loaded" << m_allocations.size() << "allocations";
        emit allocationsLoaded(m_allocations);

        // Automatically fetch apps for all allocations
        fetchAllApps();
    });
}

AirPCAllocation* AirPCApiClient::getAllocationForComputer(const QString& computerUuid)
{
    for (int i = 0; i < m_allocations.size(); i++) {
        if (m_allocations[i].computerUuid == computerUuid) {
            return &m_allocations[i];
        }
    }
    return nullptr;
}

// ============================================================================
// Apps
// ============================================================================

void AirPCApiClient::fetchAppsForAllocation(const AirPCAllocation& allocation)
{
    if (!isLoggedIn()) {
        qWarning() << "AirPCApiClient: Cannot fetch apps - not logged in";
        return;
    }

    qInfo() << "AirPCApiClient: Fetching apps for" << allocation.computerName;

    QString endpoint = QString("/api/v1/computer/%1/apps").arg(allocation.computerUuid);
    QNetworkRequest request = createRequest(m_apiBaseUrl + endpoint);
    QNetworkReply* reply = m_nam.get(request);

    connect(reply, &QNetworkReply::finished, this, [this, reply, allocation]() {
        reply->deleteLater();

        if (reply->error() != QNetworkReply::NoError) {
            qWarning() << "AirPCApiClient: Failed to fetch apps for" << allocation.computerName
                       << ":" << reply->errorString();
            return;
        }

        QByteArray data = reply->readAll();
        QJsonDocument doc = QJsonDocument::fromJson(data);
        QJsonObject json = doc.object();

        if (!json["success"].toBool()) {
            qWarning() << "AirPCApiClient: Apps API error for" << allocation.computerName
                       << ":" << json["message"].toString();
            return;
        }

        QJsonArray appsArray = json["apps"].toArray();
        for (const QJsonValue& value : appsArray) {
            m_apps.append(AirPCPublicApp::fromJson(value.toObject(), allocation));
        }

        qInfo() << "AirPCApiClient: Loaded" << appsArray.size() << "apps from" << allocation.computerName;
    });
}

void AirPCApiClient::fetchAllApps()
{
    if (m_allocations.isEmpty()) {
        qInfo() << "AirPCApiClient: No allocations to fetch apps from";
        emit appsLoaded(m_apps);
        return;
    }

    m_apps.clear();
    int total = m_allocations.size();
    int* loadedCount = new int(0);

    for (const AirPCAllocation& allocation : m_allocations) {
        QString endpoint = QString("/api/v1/computer/%1/apps").arg(allocation.computerUuid);
        QNetworkRequest request = createRequest(m_apiBaseUrl + endpoint);
        QNetworkReply* reply = m_nam.get(request);

        connect(reply, &QNetworkReply::finished, this, [this, reply, allocation, loadedCount, total]() {
            reply->deleteLater();
            (*loadedCount)++;

            if (reply->error() == QNetworkReply::NoError) {
                QByteArray data = reply->readAll();
                QJsonDocument doc = QJsonDocument::fromJson(data);
                QJsonObject json = doc.object();

                if (json["success"].toBool()) {
                    QJsonArray appsArray = json["apps"].toArray();
                    for (const QJsonValue& value : appsArray) {
                        m_apps.append(AirPCPublicApp::fromJson(value.toObject(), allocation));
                    }
                    qInfo() << "AirPCApiClient: Loaded" << appsArray.size() 
                            << "apps from" << allocation.computerName;
                }
            } else {
                qWarning() << "AirPCApiClient: Failed to load apps from" << allocation.computerName;
            }

            emit appsLoadProgress(*loadedCount, total);

            if (*loadedCount >= total) {
                qInfo() << "AirPCApiClient: All apps loaded, total:" << m_apps.size();
                emit appsLoaded(m_apps);
                delete loadedCount;
            }
        });
    }
}

// ============================================================================
// Stream Management
// ============================================================================

void AirPCApiClient::launchStream(const QString& computerUuid, const QString& appId, const QString& appUuid)
{
    if (!isLoggedIn()) {
        qWarning() << "AirPCApiClient: Cannot launch stream - not logged in";
        emit streamLaunchFailed("Not logged in");
        return;
    }

    qInfo() << "AirPCApiClient: Launching stream for app" << appId << "on computer" << computerUuid;

    m_isLoading = true;
    emit loadingChanged();

    QNetworkRequest request = createRequest(m_apiBaseUrl + "/api/v1/allocations/stream/launch");
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");

    AirPCStreamLaunchRequest launchRequest;
    launchRequest.computerUuid = computerUuid;
    launchRequest.appId = appId;
    launchRequest.appUuid = appUuid;
    launchRequest.deviceId = getDeviceId();

    QNetworkReply* reply = m_nam.post(request, QJsonDocument(launchRequest.toJson()).toJson());

    connect(reply, &QNetworkReply::finished, this, [this, reply, computerUuid, appId]() {
        m_isLoading = false;
        emit loadingChanged();
        reply->deleteLater();

        if (reply->error() != QNetworkReply::NoError) {
            QString error = reply->errorString();
            QByteArray data = reply->readAll();
            QJsonDocument doc = QJsonDocument::fromJson(data);
            if (doc.isObject() && doc.object().contains("message")) {
                error = doc.object()["message"].toString();
            }
            qWarning() << "AirPCApiClient: Stream launch failed:" << error;
            emit streamLaunchFailed(error);
            return;
        }

        QByteArray data = reply->readAll();
        QJsonDocument doc = QJsonDocument::fromJson(data);
        AirPCStreamLaunchResponse response = AirPCStreamLaunchResponse::fromJson(doc.object());

        if (!response.success) {
            qWarning() << "AirPCApiClient: Stream launch rejected:" << response.message;
            emit streamLaunchFailed(response.message);
            return;
        }

        qInfo() << "AirPCApiClient: Stream launched successfully";
        qInfo() << "  Session ID:" << response.sessionId;
        qInfo() << "  Stream host:" << response.streamHost << ":" << response.streamPort;
        qInfo() << "  HTTPS port:" << response.streamHttpsPort;
        qInfo() << "  Playtime:" << response.playtimeSeconds << "seconds";

        // Find app name from local cache
        QString appName = "Unknown";
        for (const AirPCPublicApp& app : m_apps) {
            if (app.id == appId && app.computerUuid == computerUuid) {
                appName = app.title;
                break;
            }
        }

        // Find allocation for this computer
        AirPCAllocation* allocation = getAllocationForComputer(computerUuid);

        // Create and save active session
        AirPCActiveSession session;
        session.sessionId = response.sessionId;
        session.allocationId = response.allocationId;
        session.accountId = allocation ? allocation->accountId : 0;
        session.computerUuid = computerUuid;
        session.computerName = response.computerName;
        session.hostname = response.streamHost;
        session.port = response.streamPort;
        session.httpsPort = response.streamHttpsPort;
        session.appId = appId;
        session.appName = appName;
        session.sessionToken = response.sessionToken;
        session.startedAt = QDateTime::currentMSecsSinceEpoch();
        session.playtimeSeconds = response.playtimeSeconds;
        session.lastConnected = QDateTime::currentMSecsSinceEpoch();

        saveActiveSession(session);

        emit streamLaunched(response);
    });
}

// ============================================================================
// Host Control - Quit App
// ============================================================================

void AirPCApiClient::quitAppOnHost()
{
    if (!hasActiveSession()) {
        qWarning() << "AirPCApiClient: No active session for quitAppOnHost";
        return;
    }

    qInfo() << "AirPCApiClient: Attempting to quit app on host" << m_activeSession.hostname;

    try {
        // Create NvHTTP with the host address from the saved session
        // Using the HTTPS port for secure communication
        NvAddress address(m_activeSession.hostname, static_cast<uint16_t>(m_activeSession.port));
        uint16_t httpsPort = static_cast<uint16_t>(m_activeSession.httpsPort > 0 ? m_activeSession.httpsPort : 47984);
        
        NvHTTP http(address, httpsPort, QSslCertificate());
        
        // Set session token for API-based authentication (bypasses certificate checks)
        http.setSessionToken(m_activeSession.sessionToken);
        
        // Set Go API base URL for host control token minting
        http.setGoApiBaseUrl(m_apiBaseUrl);
        
        qInfo() << "AirPCApiClient: Sending quit command to" << m_activeSession.hostname 
                << ":" << httpsPort;
        
        // Send quit command
        http.quitApp();
        
        qInfo() << "AirPCApiClient: Successfully quit app on host";
        
    } catch (const GfeHttpResponseException& e) {
        // Error code 599 means the app wasn't started by this client - ignore
        if (e.getStatusCode() == 599) {
            qWarning() << "AirPCApiClient: Host refused quit command (app not started by this client)";
        } else {
            qWarning() << "AirPCApiClient: Failed to quit app on host:" << e.toQString();
        }
    } catch (const QtNetworkReplyException& e) {
        qWarning() << "AirPCApiClient: Network error quitting app on host:" << e.toQString();
    } catch (const std::exception& e) {
        qWarning() << "AirPCApiClient: Exception quitting app on host:" << e.what();
    }
}

void AirPCApiClient::endSession()
{
    if (!hasActiveSession()) {
        qWarning() << "AirPCApiClient: No active session to end";
        return;
    }

    qInfo() << "AirPCApiClient: Ending session" << m_activeSession.sessionId;

    // Step 1: Try to quit the app on the host first (matching Android's quitAppOnHost)
    // This sends a quit command via NvHTTP to gracefully stop the game
    quitAppOnHost();

    // Step 2: Send end session request to API
    QNetworkRequest request = createRequest(m_apiBaseUrl + "/api/v1/sessions/end", false);
    request.setRawHeader("X-Session-Token", m_activeSession.sessionToken.toUtf8());

    QNetworkReply* reply = m_nam.post(request, QByteArray());
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) {
            qWarning() << "AirPCApiClient: End session API call failed (proceeding anyway):" 
                       << reply->errorString();
        } else {
            qInfo() << "AirPCApiClient: Session ended via API";
        }
    });

    // Step 3: Clear local session
    clearActiveSession();
    emit sessionEnded();
}

void AirPCApiClient::resumeSession()
{
    if (!hasActiveSession()) {
        qWarning() << "AirPCApiClient: No active session to resume";
        return;
    }

    qInfo() << "AirPCApiClient: Resuming session" << m_activeSession.sessionId;

    // Update last connected timestamp
    m_activeSession.lastConnected = QDateTime::currentMSecsSinceEpoch();
    saveActiveSession(m_activeSession);

    // Create a synthetic launch response for the UI to handle
    // Include appId and appName from the saved session (critical for resume)
    AirPCStreamLaunchResponse response;
    response.success = true;
    response.sessionId = m_activeSession.sessionId;
    response.sessionToken = m_activeSession.sessionToken;
    response.streamHost = m_activeSession.hostname;
    response.streamPort = m_activeSession.port;
    response.streamHttpsPort = m_activeSession.httpsPort;
    response.playtimeSeconds = m_activeSession.playtimeSeconds;
    response.computerUuid = m_activeSession.computerUuid;
    response.computerName = m_activeSession.computerName;
    response.appId = m_activeSession.appId;
    response.appName = m_activeSession.appName;
    
    qInfo() << "AirPCApiClient: Resume response - App:" << response.appName 
            << "ID:" << response.appId;

    emit streamLaunched(response);
}

// ============================================================================
// Session Persistence
// ============================================================================

void AirPCApiClient::saveActiveSession(const AirPCActiveSession& session)
{
    m_activeSession = session;
    QJsonDocument doc(session.toJson());
    m_settings.setValue("airpc/active_session", doc.toJson());
    m_settings.sync();
    qInfo() << "AirPCApiClient: Saved active session to disk";
    emit activeSessionChanged();
}

void AirPCApiClient::clearActiveSession()
{
    m_activeSession = AirPCActiveSession();
    m_settings.remove("airpc/active_session");
    m_settings.sync();
    qInfo() << "AirPCApiClient: Cleared active session";
    emit activeSessionChanged();
}

void AirPCApiClient::loadActiveSession()
{
    QByteArray data = m_settings.value("airpc/active_session").toByteArray();
    if (data.isEmpty()) {
        return;
    }

    QJsonDocument doc = QJsonDocument::fromJson(data);
    if (doc.isObject()) {
        m_activeSession = AirPCActiveSession::fromJson(doc.object());
        if (m_activeSession.isValid()) {
            qInfo() << "AirPCApiClient: Loaded active session:" << m_activeSession.sessionId;
            emit activeSessionChanged();
        }
    }
}

// ============================================================================
// Profile
// ============================================================================

void AirPCApiClient::fetchProfile()
{
    if (!isLoggedIn()) {
        qWarning() << "AirPCApiClient: Cannot fetch profile - not logged in";
        return;
    }

    QNetworkRequest request = createRequest(m_apiBaseUrl + "/api/v1/profile");
    QNetworkReply* reply = m_nam.get(request);

    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();

        if (reply->error() != QNetworkReply::NoError) {
            qWarning() << "AirPCApiClient: Failed to fetch profile:" << reply->errorString();
            return;
        }

        QByteArray data = reply->readAll();
        QJsonDocument doc = QJsonDocument::fromJson(data);
        QJsonObject json = doc.object();

        if (json["success"].toBool()) {
            AirPCUserProfile profile = AirPCUserProfile::fromJson(json);
            qInfo() << "AirPCApiClient: Profile loaded for" << profile.username;
            emit profileLoaded(profile.playtimeSeconds, profile.claimCount, profile.username, profile.email);
        }
    });
}

// ============================================================================
// Heartbeat
// ============================================================================

void AirPCApiClient::sendHeartbeat()
{
    if (!hasActiveSession()) {
        qWarning() << "AirPCApiClient: Cannot send heartbeat - no active session";
        emit heartbeatFailed("No active session");
        return;
    }

    QUrl url(m_apiBaseUrl + "/api/v1/sessions/heartbeat");
    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    request.setRawHeader("X-Session-Token", m_activeSession.sessionToken.toUtf8());
    request.setTransferTimeout(CONNECTION_TIMEOUT_MS);

    // Build heartbeat data
    QJsonObject body;
    body["device_id"] = getDeviceId();

    QNetworkReply* reply = m_nam.post(request, QJsonDocument(body).toJson());

    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();

        if (reply->error() != QNetworkReply::NoError) {
            qWarning() << "AirPCApiClient: Heartbeat failed:" << reply->errorString();
            emit heartbeatFailed(reply->errorString());
            return;
        }

        QByteArray data = reply->readAll();
        QJsonDocument doc = QJsonDocument::fromJson(data);
        AirPCHeartbeatResponse resp = AirPCHeartbeatResponse::fromJson(doc.object());

        qDebug() << "AirPCApiClient: Heartbeat received - valid:" << resp.valid
                 << "remaining:" << resp.remainingSeconds << "s"
                 << "idleWarning:" << resp.idleWarning;

        emit heartbeatReceived(resp.valid, resp.remainingSeconds, resp.remainingPlaytime,
                               resp.idleWarning, resp.idleSeconds, resp.message);
    });
}

// ============================================================================
// Claims
// ============================================================================

void AirPCApiClient::claimOrder(const QString& orderSn)
{
    if (!isLoggedIn()) {
        emit claimFailed("Not logged in");
        return;
    }

    qInfo() << "AirPCApiClient: Claiming order" << orderSn;

    QNetworkRequest request = createRequest(m_apiBaseUrl + "/api/v1/claims");
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");

    QJsonObject body;
    body["order_sn"] = orderSn;

    QNetworkReply* reply = m_nam.post(request, QJsonDocument(body).toJson());

    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();

        if (reply->error() != QNetworkReply::NoError) {
            QString error = reply->errorString();
            QByteArray data = reply->readAll();
            QJsonDocument doc = QJsonDocument::fromJson(data);
            if (doc.isObject() && doc.object().contains("message")) {
                error = doc.object()["message"].toString();
            }
            qWarning() << "AirPCApiClient: Claim failed:" << error;
            emit claimFailed(error);
            return;
        }

        QByteArray data = reply->readAll();
        QJsonDocument doc = QJsonDocument::fromJson(data);
        AirPCClaimResponse resp = AirPCClaimResponse::fromJson(doc.object());

        if (!resp.success) {
            qWarning() << "AirPCApiClient: Claim rejected:" << resp.message;
            emit claimFailed(resp.message);
            return;
        }

        qInfo() << "AirPCApiClient: Claim successful - granted:" << resp.playtimeGranted
                << "total:" << resp.totalPlaytime;
        emit claimSucceeded(resp.playtimeGranted, resp.totalPlaytime);
    });
}

void AirPCApiClient::fetchClaimHistory()
{
    if (!isLoggedIn()) {
        emit claimHistoryReceived(QVariantList());
        return;
    }

    QNetworkRequest request = createRequest(m_apiBaseUrl + "/api/v1/claims");
    QNetworkReply* reply = m_nam.get(request);

    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();

        QVariantList claimsList;

        if (reply->error() != QNetworkReply::NoError) {
            qWarning() << "AirPCApiClient: Failed to fetch claim history:" << reply->errorString();
            emit claimHistoryReceived(claimsList);
            return;
        }

        QByteArray data = reply->readAll();
        QJsonDocument doc = QJsonDocument::fromJson(data);
        QJsonObject json = doc.object();

        if (json["success"].toBool()) {
            QJsonArray claimsArray = json["claims"].toArray();
            for (const QJsonValue& val : claimsArray) {
                AirPCOrderClaim claim = AirPCOrderClaim::fromJson(val.toObject());
                QVariantMap claimMap;
                claimMap["claimId"] = claim.claimId;
                claimMap["orderSn"] = claim.orderSn;
                claimMap["playtimeGranted"] = claim.playtimeGranted;
                claimMap["claimedAt"] = claim.claimedAt;
                claimsList.append(claimMap);
            }
            qInfo() << "AirPCApiClient: Loaded" << claimsList.size() << "claim history entries";
        }

        emit claimHistoryReceived(claimsList);
    });
}

// ============================================================================
// Helpers
// ============================================================================

QNetworkRequest AirPCApiClient::createRequest(const QString& endpoint, bool authenticated)
{
    QUrl url(endpoint);
    QNetworkRequest request;
    request.setUrl(url);
    request.setTransferTimeout(READ_TIMEOUT_MS);

    if (authenticated && !m_authToken.isEmpty()) {
        request.setRawHeader("Authorization", QString("Bearer %1").arg(m_authToken).toUtf8());
    }

    return request;
}

void AirPCApiClient::handleNetworkError(QNetworkReply* reply)
{
    QString error = reply->errorString();
    QByteArray data = reply->readAll();
    QJsonDocument doc = QJsonDocument::fromJson(data);
    if (doc.isObject() && doc.object().contains("message")) {
        error = doc.object()["message"].toString();
    }
    qWarning() << "AirPCApiClient: Network error:" << error;
    m_errorMessage = error;
    emit errorOccurred(error);
}

QString AirPCApiClient::getDeviceId()
{
    if (!m_deviceId.isEmpty()) {
        return m_deviceId;
    }

    // Try to load from settings
    m_deviceId = m_settings.value("airpc/device_id").toString();
    if (!m_deviceId.isEmpty()) {
        return m_deviceId;
    }

    // Generate a new device ID
    m_deviceId = QUuid::createUuid().toString(QUuid::WithoutBraces);
    m_settings.setValue("airpc/device_id", m_deviceId);
    m_settings.sync();

    qInfo() << "AirPCApiClient: Generated new device ID:" << m_deviceId;
    return m_deviceId;
}

void AirPCApiClient::setApiBaseUrl(const QString& url)
{
    m_apiBaseUrl = url;
    qInfo() << "AirPCApiClient: API base URL set to:" << m_apiBaseUrl;
}

// ============================================================================
// Credential Storage
// ============================================================================

void AirPCApiClient::saveCredentials(const QString& token, const QString& username, bool rememberMe)
{
    if (rememberMe) {
        // In production, use secure storage (Keychain, Credential Manager, libsecret)
        // For now, we use QSettings with obfuscation
        m_settings.setValue("airpc/auth_token", token);
        m_settings.setValue("airpc/username", username);
        m_settings.setValue("airpc/remember_me", true);
    } else {
        m_settings.remove("airpc/auth_token");
        m_settings.remove("airpc/username");
        m_settings.setValue("airpc/remember_me", false);
    }
    m_settings.sync();
}

void AirPCApiClient::loadCredentials()
{
    bool rememberMe = m_settings.value("airpc/remember_me", false).toBool();
    if (!rememberMe) {
        return;
    }

    QString token = m_settings.value("airpc/auth_token").toString();
    QString username = m_settings.value("airpc/username").toString();

    if (!token.isEmpty() && !isTokenExpired(token)) {
        m_authToken = token;
        m_username = username;
        qInfo() << "AirPCApiClient: Loaded saved credentials for:" << username;
    } else if (!token.isEmpty()) {
        qInfo() << "AirPCApiClient: Saved token is expired, clearing credentials";
        clearCredentials();
    }
}

void AirPCApiClient::clearCredentials()
{
    m_settings.remove("airpc/auth_token");
    m_settings.remove("airpc/username");
    m_settings.remove("airpc/remember_me");
    m_settings.sync();
}

bool AirPCApiClient::isTokenExpired(const QString& token) const
{
    qint64 expiry = extractTokenExpiry(token);
    if (expiry <= 0) {
        return false; // Can't determine expiry, assume valid
    }
    return QDateTime::currentSecsSinceEpoch() >= expiry;
}

qint64 AirPCApiClient::extractTokenExpiry(const QString& token) const
{
    // JWT tokens have 3 parts separated by dots
    QStringList parts = token.split('.');
    if (parts.size() != 3) {
        return 0;
    }

    // Decode the payload (second part)
    QByteArray payload = QByteArray::fromBase64(parts[1].toUtf8(), QByteArray::Base64UrlEncoding);
    QJsonDocument doc = QJsonDocument::fromJson(payload);
    if (!doc.isObject()) {
        return 0;
    }

    // Extract exp claim
    return doc.object()["exp"].toVariant().toLongLong();
}
