#include "airpcstreambridge.h"
#include "nvcomputer.h"
#include "nvapp.h"
#include "nvaddress.h"
#include "playtimemanager.h"
#include "../streaming/session.h"
#include "../settings/streamingpreferences.h"

#include <QDebug>
#include <QSysInfo>

// Static singleton instance
static AirPCStreamBridge* s_instance = nullptr;

AirPCStreamBridge::AirPCStreamBridge(QObject* parent)
    : QObject(parent)
    , m_currentSession(nullptr)
    , m_syntheticComputer(nullptr)
{
    qInfo() << "AirPCStreamBridge initialized";
}

AirPCStreamBridge::~AirPCStreamBridge()
{
    cleanup();
}

AirPCStreamBridge* AirPCStreamBridge::get()
{
    if (!s_instance) {
        s_instance = new AirPCStreamBridge();
    }
    return s_instance;
}

void AirPCStreamBridge::setPlaytimeManager(PlaytimeManager* manager)
{
    m_playtimeManager = manager;
    qInfo() << "AirPCStreamBridge: PlaytimeManager connected";
}

void AirPCStreamBridge::launchFromApiResponse(
    const AirPCStreamLaunchResponse& response,
    const QString& appName,
    int appId)
{
    qInfo() << "AirPCStreamBridge: Launching stream from API response";
    qInfo() << "  App:" << appName << "ID:" << appId;
    qInfo() << "  Host:" << response.streamHost << "Port:" << response.streamPort;
    qInfo() << "  Computer:" << response.computerName << "UUID:" << response.computerUuid;
    
    // Validate the response
    if (!response.success) {
        QString error = response.message.isEmpty() 
            ? tr("Stream launch failed: Unknown error")
            : tr("Stream launch failed: %1").arg(response.message);
        qWarning() << "AirPCStreamBridge:" << error;
        emit launchError(error);
        return;
    }
    
    if (response.streamHost.isEmpty()) {
        QString error = tr("Stream launch failed: No stream host provided");
        qWarning() << "AirPCStreamBridge:" << error;
        emit launchError(error);
        return;
    }
    
    if (response.streamPort == 0) {
        QString error = tr("Stream launch failed: Invalid stream port");
        qWarning() << "AirPCStreamBridge:" << error;
        emit launchError(error);
        return;
    }
    
    // Clean up any previous session
    cleanup();
    
    // Store the app name for later use
    m_currentAppName = appName;
    
    // Create synthetic computer from API response
    m_syntheticComputer = createSyntheticComputer(response);
    if (!m_syntheticComputer) {
        QString error = tr("Stream launch failed: Could not create computer configuration");
        qWarning() << "AirPCStreamBridge:" << error;
        emit launchError(error);
        return;
    }
    
    // Create the app object
    NvApp app = createApp(appName, appId);
    
    // Get streaming preferences (use defaults if not available)
    StreamingPreferences* prefs = StreamingPreferences::get();
    
    // Create the session
    m_currentSession = new Session(m_syntheticComputer, app, prefs);
    
    // Connect session signals to our slots
    connect(m_currentSession, &Session::stageStarting,
            this, &AirPCStreamBridge::onSessionStageStarting);
    connect(m_currentSession, &Session::stageFailed,
            this, &AirPCStreamBridge::onSessionStageFailed);
    connect(m_currentSession, &Session::displayLaunchError,
            this, &AirPCStreamBridge::onSessionDisplayLaunchError);
    connect(m_currentSession, &Session::sessionFinished,
            this, &AirPCStreamBridge::onSessionFinished);
    connect(m_currentSession, &Session::readyForDeletion,
            this, &AirPCStreamBridge::onSessionReadyForDeletion);
    
    qInfo() << "AirPCStreamBridge: Session created, emitting sessionCreated signal";
    
    // Store session info for playtime tracking
    m_currentSessionToken = response.sessionToken;
    m_currentPlaytimeSeconds = response.playtimeSeconds;
    
    // Emit the session for QML to use (follows the pattern from startstream.cpp)
    // The QML side will call session.exec(window) to actually start streaming
    emit sessionCreated(appName, m_currentSession);
    emit streamStarted();
    
    // Start playtime tracking if we have a PlaytimeManager and playtime available
    if (m_playtimeManager && m_currentPlaytimeSeconds > 0) {
        qInfo() << "AirPCStreamBridge: Starting playtime tracking with" << m_currentPlaytimeSeconds << "seconds";
        m_playtimeManager->startSession(m_currentSessionToken, m_currentPlaytimeSeconds);
    }
}

bool AirPCStreamBridge::isStreamActive() const
{
    return m_currentSession != nullptr;
}

Session* AirPCStreamBridge::currentSession() const
{
    return m_currentSession;
}

NvComputer* AirPCStreamBridge::createSyntheticComputer(const AirPCStreamLaunchResponse& response)
{
    qInfo() << "AirPCStreamBridge: Fetching real serverinfo from Apollo";
    
    // Create NvHTTP instance pointing to the Apollo server
    NvAddress serverAddress(response.streamHost, static_cast<uint16_t>(response.streamPort));
    uint16_t httpsPort = static_cast<uint16_t>(response.streamHttpsPort);

    if (httpsPort == 0) {
        qInfo() << "AirPCStreamBridge: streamHttpsPort is 0. Attempting to discover via HTTP GET /serverinfo...";
        NvHTTP httpDiscovery(serverAddress, 0, QSslCertificate());
        try {
            // true for fastFail so we don't hang too long on dead hosts
            QString discoveryInfo = httpDiscovery.getServerInfo(NvHTTP::NVLL_ERROR, true);
            QString portStr = NvHTTP::getXmlString(discoveryInfo, "HttpsPort");
            if (!portStr.isEmpty() && portStr.toUShort() > 0) {
                httpsPort = portStr.toUShort();
                qInfo() << "AirPCStreamBridge: Discovered HTTPS port:" << httpsPort;
            } else {
                httpsPort = DEFAULT_HTTPS_PORT;
                qWarning() << "AirPCStreamBridge: HTTPS port not in XML, defaulting to" << httpsPort;
            }
        } catch (const std::exception& e) {
            httpsPort = DEFAULT_HTTPS_PORT;
            qWarning() << "AirPCStreamBridge: Discovery failed, defaulting to" << httpsPort << ". Error:" << e.what();
        }
    }

    // Create NvHTTP with empty cert - we'll use token auth instead
    NvHTTP http(serverAddress, httpsPort, QSslCertificate());
    
    // Set session token for API-based authentication (bypasses cert check)
    http.setSessionToken(response.sessionToken);
    
    // Set API URL and device ID for host token minting
    http.setGoApiBaseUrl(AirPCApiClient::get()->apiBaseUrl());
    http.setDeviceId(AirPCApiClient::get()->getDeviceId());
    
    try {
        // Fetch real serverinfo from Apollo (token auth used automatically)
        QString serverInfo = http.getServerInfo(NvHTTP::NVLL_VERBOSE);
        
        qInfo() << "AirPCStreamBridge: Got serverinfo from Apollo";
        
        // Create NvComputer from real server data
        NvComputer* computer = new NvComputer(http, serverInfo);
        
        // Override with API session fields that aren't in serverinfo
        computer->isApiSession = true;
        computer->sessionToken = response.sessionToken;
        computer->sessionId = response.sessionId;
        computer->playtimeSeconds = response.playtimeSeconds;
        computer->goApiBaseUrl = AirPCApiClient::get()->apiBaseUrl();
        computer->deviceId = AirPCApiClient::get()->getDeviceId();
        
        // Force state to online/paired (we just got serverinfo successfully)
        computer->state = NvComputer::CS_ONLINE;
        computer->pairState = NvComputer::PS_PAIRED;

        // API-session launches are token-authorized and should not be blocked by
        // GeForce Experience compatibility matrix checks.
        computer->isSupportedServerVersion = true;
        
        qInfo() << "AirPCStreamBridge: Computer created from real serverinfo:"
                << "name:" << computer->name
                << "uuid:" << computer->uuid
                << "appVersion:" << computer->appVersion
                << "gfeVersion:" << computer->gfeVersion
                << "apolloVersion:" << computer->apolloVersion
                << "isNvidiaServerSoftware:" << computer->isNvidiaServerSoftware
                << "isApiSession:" << computer->isApiSession
                << "isSupportedServerVersion:" << computer->isSupportedServerVersion
                << "serverCodecModeSupport:" << computer->serverCodecModeSupport
                << "maxLumaPixelsHEVC:" << computer->maxLumaPixelsHEVC;
        
        return computer;
    }
    catch (const GfeHttpResponseException& e) {
        qWarning() << "AirPCStreamBridge: Failed to fetch serverinfo, using fallback computer:" << e.toQString();
        return createFallbackComputer(response);
    }
    catch (const QtNetworkReplyException& e) {
        qWarning() << "AirPCStreamBridge: Network error fetching serverinfo, using fallback computer:" << e.toQString();
        return createFallbackComputer(response);
    }
}

NvComputer* AirPCStreamBridge::createFallbackComputer(const AirPCStreamLaunchResponse& response) const
{
    NvComputer* computer = new NvComputer();

    computer->name = response.computerName.isEmpty() ? response.streamHost : response.computerName;
    computer->uuid = response.computerUuid;
    computer->activeAddress = NvAddress(response.streamHost, static_cast<uint16_t>(response.streamPort));
    computer->activeHttpsPort = static_cast<uint16_t>(response.streamHttpsPort > 0 ? response.streamHttpsPort : DEFAULT_HTTPS_PORT);
    computer->state = NvComputer::CS_ONLINE;
    computer->pairState = NvComputer::PS_PAIRED;
    computer->isSupportedServerVersion = true;

    computer->isApiSession = true;
    computer->sessionToken = response.sessionToken;
    computer->sessionId = response.sessionId;
    computer->playtimeSeconds = response.playtimeSeconds;
    computer->goApiBaseUrl = AirPCApiClient::get()->apiBaseUrl();
    computer->deviceId = AirPCApiClient::get()->getDeviceId();

    qInfo() << "AirPCStreamBridge: Fallback computer created"
            << "name:" << computer->name
            << "uuid:" << computer->uuid
            << "host:" << response.streamHost
            << "rtspPort:" << response.streamPort
            << "httpsPort:" << computer->activeHttpsPort;

    return computer;
}

NvApp AirPCStreamBridge::createApp(const QString& name, int id)
{
    NvApp app;
    app.id = id;
    app.name = name;
    app.hdrSupported = false; // Conservative default
    app.isAppCollectorGame = false;
    app.hidden = false;
    app.directLaunch = false;
    
    qInfo() << "AirPCStreamBridge: Created app:" << app.name << "ID:" << app.id;
    
    return app;
}

void AirPCStreamBridge::cleanup()
{
    if (m_currentSession) {
        qInfo() << "AirPCStreamBridge: Cleaning up current session";
        // Don't delete the session here - it will be deleted when readyForDeletion is emitted
        // Just clear our reference
        m_currentSession = nullptr;
    }
    
    if (m_syntheticComputer) {
        qInfo() << "AirPCStreamBridge: Cleaning up synthetic computer";
        delete m_syntheticComputer;
        m_syntheticComputer = nullptr;
    }
    
    m_currentAppName.clear();
    m_currentSessionToken.clear();
    m_currentPlaytimeSeconds = 0;
}

// Session signal handlers

void AirPCStreamBridge::onSessionStageStarting(const QString& stage)
{
    qInfo() << "AirPCStreamBridge: Stage starting:" << stage;
}

void AirPCStreamBridge::onSessionStageFailed(const QString& stage, int errorCode, const QString& failingPorts)
{
    QString error = tr("Connection failed at stage '%1' (error %2)").arg(stage).arg(errorCode);
    if (!failingPorts.isEmpty()) {
        error += tr(". Check firewall for ports: %1").arg(failingPorts);
    }
    qWarning() << "AirPCStreamBridge:" << error;
    emit launchError(error);
}

void AirPCStreamBridge::onSessionDisplayLaunchError(const QString& text)
{
    qWarning() << "AirPCStreamBridge: Launch error:" << text;
    emit launchError(text);
}

void AirPCStreamBridge::onSessionFinished(int portTestResult)
{
    qInfo() << "AirPCStreamBridge: Session finished, port test result:" << portTestResult;
    
    // Stop playtime tracking
    if (m_playtimeManager) {
        qInfo() << "AirPCStreamBridge: Stopping playtime tracking";
        m_playtimeManager->endSession();
    }
    
    QString reason;
    if (portTestResult == 0) {
        reason = tr("Stream ended normally");
    } else if (portTestResult == -1) {
        reason = tr("Stream ended");
    } else {
        reason = tr("Stream ended (network issues detected)");
    }
    
    emit streamEnded(reason);
}

void AirPCStreamBridge::onSessionReadyForDeletion()
{
    qInfo() << "AirPCStreamBridge: Session ready for deletion";
    
    // Now we can safely clean up
    if (m_currentSession) {
        m_currentSession->deleteLater();
        m_currentSession = nullptr;
    }
    
    // Clean up the synthetic computer too
    if (m_syntheticComputer) {
        delete m_syntheticComputer;
        m_syntheticComputer = nullptr;
    }
    
    m_currentAppName.clear();
}
