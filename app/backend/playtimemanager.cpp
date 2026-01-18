#include "playtimemanager.h"
#include "airpcapiclient.h"
#include <QDebug>

PlaytimeManager::PlaytimeManager(AirPCApiClient* apiClient, QObject* parent)
    : QObject(parent)
    , m_apiClient(apiClient)
    , m_tracker(new PlaytimeTracker(this))
    , m_heartbeatTimer(new QTimer(this))
{
    // Connect tracker signals
    connect(m_tracker, &PlaytimeTracker::remainingSecondsChanged,
            this, &PlaytimeManager::remainingSecondsChanged);
    connect(m_tracker, &PlaytimeTracker::warningThreshold,
            this, &PlaytimeManager::onTrackerWarning);
    connect(m_tracker, &PlaytimeTracker::playtimeExpired,
            this, &PlaytimeManager::onTrackerExpired);

    // Connect heartbeat timer
    m_heartbeatTimer->setInterval(HEARTBEAT_INTERVAL_MS);
    connect(m_heartbeatTimer, &QTimer::timeout, this, &PlaytimeManager::onHeartbeatTick);

    // Connect API client signals
    connect(m_apiClient, &AirPCApiClient::heartbeatReceived,
            this, &PlaytimeManager::onHeartbeatReceived);
    connect(m_apiClient, &AirPCApiClient::heartbeatFailed,
            this, &PlaytimeManager::onHeartbeatFailed);
    
    // Connect profile signal - now uses individual parameters
    connect(m_apiClient, &AirPCApiClient::profileLoaded, this,
            &PlaytimeManager::onProfileReceived);
}

PlaytimeManager::~PlaytimeManager()
{
    endSession();
}

int PlaytimeManager::remainingSeconds() const
{
    return m_tracker->remainingSeconds();
}

QString PlaytimeManager::formattedRemaining() const
{
    return m_tracker->formattedTime();
}

QString PlaytimeManager::formattedBalance() const
{
    return formatSeconds(m_accountBalance);
}

QString PlaytimeManager::formatSeconds(int seconds) const
{
    if (seconds <= 0) return "0m";

    int hours = seconds / 3600;
    int minutes = (seconds % 3600) / 60;

    if (hours > 0 && minutes > 0) {
        return QString("%1h %2m").arg(hours).arg(minutes);
    } else if (hours > 0) {
        return QString("%1h").arg(hours);
    } else {
        return QString("%1m").arg(minutes);
    }
}

void PlaytimeManager::startSession(const QString& sessionToken, int initialPlaytimeSeconds)
{
    qInfo() << "PlaytimeManager: Starting session with" << initialPlaytimeSeconds << "seconds";

    m_sessionToken = sessionToken;
    m_isSessionActive = true;
    m_idleWarning = false;

    // Start local countdown tracker
    m_tracker->start(initialPlaytimeSeconds);

    // Start heartbeat timer (first heartbeat after interval)
    m_heartbeatTimer->start();

    emit sessionActiveChanged();
    emit idleWarningChanged();
}

void PlaytimeManager::endSession()
{
    if (!m_isSessionActive) return;

    qInfo() << "PlaytimeManager: Ending session";

    m_heartbeatTimer->stop();
    m_tracker->stop();
    m_sessionToken.clear();
    m_isSessionActive = false;
    m_idleWarning = false;

    emit sessionActiveChanged();
    emit idleWarningChanged();
}

void PlaytimeManager::pauseSession()
{
    if (!m_isSessionActive) return;

    qInfo() << "PlaytimeManager: Pausing session";
    m_heartbeatTimer->stop();
    m_tracker->pause();
}

void PlaytimeManager::resumeSession()
{
    if (!m_isSessionActive) return;

    qInfo() << "PlaytimeManager: Resuming session";
    m_tracker->resume();
    m_heartbeatTimer->start();

    // Send immediate heartbeat on resume
    onHeartbeatTick();
}

void PlaytimeManager::refreshProfile()
{
    m_apiClient->fetchProfile();
}

void PlaytimeManager::onHeartbeatTick()
{
    if (!m_isSessionActive || m_sessionToken.isEmpty()) return;

    qDebug() << "PlaytimeManager: Sending heartbeat";
    m_apiClient->sendHeartbeat();
}

void PlaytimeManager::onHeartbeatReceived(bool valid, int remainingSeconds, int remainingPlaytime,
                                          bool idleWarning, int idleSeconds, const QString& message)
{
    if (!valid) {
        qWarning() << "PlaytimeManager: Session invalidated by server:" << message;
        endSession();
        emit sessionExpired();
        return;
    }

    // Sync local tracker with server time
    m_tracker->syncFromServer(remainingSeconds);

    // Update account balance
    if (m_accountBalance != remainingPlaytime) {
        m_accountBalance = remainingPlaytime;
        emit accountBalanceChanged();
    }

    // Handle idle warning
    if (idleWarning != m_idleWarning) {
        m_idleWarning = idleWarning;
        m_idleSeconds = idleSeconds;
        emit idleWarningChanged();

        if (idleWarning) {
            // Calculate minutes until idle timeout (20 min total, warn at 15 min)
            int idleTimeoutSeconds = 1200; // 20 minutes
            int minutesRemaining = qMax(1, (idleTimeoutSeconds - idleSeconds) / 60);
            emit idleTimeoutWarning(minutesRemaining);
        }
    }
}

void PlaytimeManager::onHeartbeatFailed(const QString& error)
{
    qWarning() << "PlaytimeManager: Heartbeat failed:" << error;
    // Don't end session on transient failures - keep local timer running
}

void PlaytimeManager::onTrackerWarning(int secondsRemaining, const QString& message)
{
    qInfo() << "PlaytimeManager: Warning at" << secondsRemaining << "seconds -" << message;
    emit warningMessage(message);
}

void PlaytimeManager::onTrackerExpired()
{
    qInfo() << "PlaytimeManager: Playtime expired locally";
    // Server will also terminate - this is just for UI feedback
    emit sessionExpired();
}

void PlaytimeManager::onProfileReceived(int playtimeSeconds, int claimCount,
                                        const QString& username, const QString& email)
{
    Q_UNUSED(claimCount)
    Q_UNUSED(username)
    Q_UNUSED(email)

    if (m_accountBalance != playtimeSeconds) {
        m_accountBalance = playtimeSeconds;
        emit accountBalanceChanged();
    }
}
