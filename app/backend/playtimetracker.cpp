#include "playtimetracker.h"
#include <QDebug>

// Warning thresholds matching Android: 5 min, 1 min, 30 sec, 10 sec
const QMap<int, QString> PlaytimeTracker::s_warningThresholds = {
    {300, QObject::tr("5 minutes remaining")},
    {60, QObject::tr("1 minute remaining - session will end soon")},
    {30, QObject::tr("30 seconds remaining")},
    {10, QObject::tr("10 seconds remaining")}
};

PlaytimeTracker::PlaytimeTracker(QObject* parent)
    : QObject(parent)
    , m_timer(new QTimer(this))
{
    m_timer->setInterval(1000); // 1 second tick
    connect(m_timer, &QTimer::timeout, this, &PlaytimeTracker::onTick);
}

PlaytimeTracker::~PlaytimeTracker()
{
    stop();
}

QString PlaytimeTracker::formattedTime() const
{
    if (m_remainingSeconds <= 0) {
        return QStringLiteral("0:00");
    }

    int hours = m_remainingSeconds / 3600;
    int minutes = (m_remainingSeconds % 3600) / 60;
    int seconds = m_remainingSeconds % 60;

    if (hours > 0) {
        return QStringLiteral("%1:%2:%3")
            .arg(hours)
            .arg(minutes, 2, 10, QChar('0'))
            .arg(seconds, 2, 10, QChar('0'));
    } else {
        return QStringLiteral("%1:%2")
            .arg(minutes)
            .arg(seconds, 2, 10, QChar('0'));
    }
}

void PlaytimeTracker::start(int totalSeconds)
{
    qInfo() << "PlaytimeTracker: Starting with" << totalSeconds << "seconds";

    m_totalSeconds = totalSeconds;
    m_remainingSeconds = totalSeconds;
    m_triggeredWarnings.clear();
    m_isPaused = false;
    m_isRunning = true;

    m_timer->start();

    emit remainingSecondsChanged();
    emit isRunningChanged();
}

void PlaytimeTracker::stop()
{
    if (!m_isRunning) return;

    qInfo() << "PlaytimeTracker: Stopped with" << m_remainingSeconds << "seconds remaining";

    m_timer->stop();
    m_isRunning = false;
    m_isPaused = false;

    emit isRunningChanged();
}

void PlaytimeTracker::pause()
{
    if (!m_isRunning || m_isPaused) return;

    qInfo() << "PlaytimeTracker: Paused";
    m_timer->stop();
    m_isPaused = true;
}

void PlaytimeTracker::resume()
{
    if (!m_isRunning || !m_isPaused) return;

    if (m_remainingSeconds <= 0) {
        qWarning() << "PlaytimeTracker: Cannot resume - no time remaining";
        return;
    }

    qInfo() << "PlaytimeTracker: Resumed with" << m_remainingSeconds << "seconds";
    m_isPaused = false;
    m_timer->start();
}

void PlaytimeTracker::syncFromServer(int serverRemainingSeconds)
{
    // Server is authoritative - sync local timer if drift is significant
    int drift = qAbs(m_remainingSeconds - serverRemainingSeconds);

    if (drift > 5) { // Only sync if drift > 5 seconds
        qInfo() << "PlaytimeTracker: Syncing from server - was" << m_remainingSeconds
                << "now" << serverRemainingSeconds << "(drift:" << drift << "s)";
        m_remainingSeconds = serverRemainingSeconds;
        emit remainingSecondsChanged();
    }
}

void PlaytimeTracker::onTick()
{
    if (m_remainingSeconds <= 0) {
        stop();
        emit playtimeExpired();
        return;
    }

    m_remainingSeconds--;
    emit remainingSecondsChanged();

    checkWarningThresholds();

    if (m_remainingSeconds <= 0) {
        stop();
        emit playtimeExpired();
    }
}

void PlaytimeTracker::checkWarningThresholds()
{
    for (auto it = s_warningThresholds.constBegin(); it != s_warningThresholds.constEnd(); ++it) {
        int threshold = it.key();

        // Trigger warning when we cross the threshold (going down)
        if (m_remainingSeconds == threshold && !m_triggeredWarnings.contains(threshold)) {
            m_triggeredWarnings.insert(threshold);
            qInfo() << "PlaytimeTracker: Warning -" << it.value();
            emit warningThreshold(threshold, it.value());
        }
    }
}
