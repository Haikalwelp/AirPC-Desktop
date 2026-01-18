#pragma once

#include <QObject>
#include <QTimer>
#include "playtimetracker.h"

class AirPCApiClient;

/**
 * Coordinator class for playtime tracking.
 * Manages the heartbeat timer, local countdown tracker, and session lifecycle.
 * Exposed to QML for UI binding.
 * 
 * Mirrors the coordination done by Android's PlaytimeTracker + ApiClient combination.
 */
class PlaytimeManager : public QObject
{
    Q_OBJECT

    // Properties for QML binding
    Q_PROPERTY(int remainingSeconds READ remainingSeconds NOTIFY remainingSecondsChanged)
    Q_PROPERTY(int accountBalance READ accountBalance NOTIFY accountBalanceChanged)
    Q_PROPERTY(QString formattedRemaining READ formattedRemaining NOTIFY remainingSecondsChanged)
    Q_PROPERTY(QString formattedBalance READ formattedBalance NOTIFY accountBalanceChanged)
    Q_PROPERTY(bool isSessionActive READ isSessionActive NOTIFY sessionActiveChanged)
    Q_PROPERTY(bool idleWarning READ idleWarning NOTIFY idleWarningChanged)

public:
    explicit PlaytimeManager(AirPCApiClient* apiClient, QObject* parent = nullptr);
    ~PlaytimeManager() override;

    // Property getters
    int remainingSeconds() const;
    int accountBalance() const { return m_accountBalance; }
    QString formattedRemaining() const;
    QString formattedBalance() const;
    bool isSessionActive() const { return m_isSessionActive; }
    bool idleWarning() const { return m_idleWarning; }

    // Session lifecycle
    Q_INVOKABLE void startSession(const QString& sessionToken, int initialPlaytimeSeconds);
    Q_INVOKABLE void endSession();
    Q_INVOKABLE void pauseSession();
    Q_INVOKABLE void resumeSession();

    // Manual refresh
    Q_INVOKABLE void refreshProfile();

signals:
    void remainingSecondsChanged();
    void accountBalanceChanged();
    void sessionActiveChanged();
    void idleWarningChanged();
    void warningMessage(const QString& message);
    void sessionExpired();
    void idleTimeoutWarning(int minutesRemaining);

private slots:
    void onHeartbeatTick();
    void onHeartbeatReceived(bool valid, int remainingSeconds, int remainingPlaytime,
                             bool idleWarning, int idleSeconds, const QString& message);
    void onHeartbeatFailed(const QString& error);
    void onTrackerWarning(int secondsRemaining, const QString& message);
    void onTrackerExpired();
    void onProfileReceived(int playtimeSeconds, int claimCount, const QString& username, const QString& email);

private:
    QString formatSeconds(int seconds) const;

    AirPCApiClient* m_apiClient;
    PlaytimeTracker* m_tracker;
    QTimer* m_heartbeatTimer;

    QString m_sessionToken;
    int m_accountBalance = 0;
    bool m_isSessionActive = false;
    bool m_idleWarning = false;
    int m_idleSeconds = 0;

    static constexpr int HEARTBEAT_INTERVAL_MS = 60000; // 60 seconds
};
