#pragma once

#include <QObject>
#include <QTimer>
#include <QSet>
#include <QMap>

/**
 * Local countdown timer for playtime UI feedback.
 * This does NOT do billing - that's handled by the host server.
 * Mirrors Android's PlaytimeTracker.kt behavior.
 */
class PlaytimeTracker : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int remainingSeconds READ remainingSeconds NOTIFY remainingSecondsChanged)
    Q_PROPERTY(bool isRunning READ isRunning NOTIFY isRunningChanged)
    Q_PROPERTY(QString formattedTime READ formattedTime NOTIFY remainingSecondsChanged)

public:
    explicit PlaytimeTracker(QObject* parent = nullptr);
    ~PlaytimeTracker() override;

    int remainingSeconds() const { return m_remainingSeconds; }
    bool isRunning() const { return m_isRunning; }
    QString formattedTime() const;

public slots:
    void start(int totalSeconds);
    void stop();
    void pause();
    void resume();
    void syncFromServer(int serverRemainingSeconds);

signals:
    void remainingSecondsChanged();
    void isRunningChanged();
    void warningThreshold(int secondsRemaining, const QString& message);
    void playtimeExpired();

private slots:
    void onTick();

private:
    void checkWarningThresholds();

    QTimer* m_timer;
    int m_remainingSeconds = 0;
    int m_totalSeconds = 0;
    bool m_isRunning = false;
    bool m_isPaused = false;

    // Warning thresholds already triggered (to avoid repeating)
    QSet<int> m_triggeredWarnings;

    // Warning thresholds in seconds -> message
    static const QMap<int, QString> s_warningThresholds;
};
