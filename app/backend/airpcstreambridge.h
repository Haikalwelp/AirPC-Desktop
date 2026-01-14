#ifndef AIRPCSTREAMBRIDGE_H
#define AIRPCSTREAMBRIDGE_H

#include <QObject>
#include "airpcapiclient.h"

// Forward declarations
class NvComputer;
class NvApp;
class Session;
class StreamingPreferences;

/**
 * Bridge between AirPC API responses and the streaming Session.
 * 
 * Converts AirPCStreamLaunchResponse into synthetic NvComputer/NvApp
 * objects that can be used with the existing Session class.
 * 
 * This allows reusing all existing streaming code while using
 * API-based authentication instead of local pairing.
 */
class AirPCStreamBridge : public QObject
{
    Q_OBJECT

public:
    explicit AirPCStreamBridge(QObject* parent = nullptr);
    ~AirPCStreamBridge();

    /**
     * Get the singleton instance.
     */
    static AirPCStreamBridge* get();

    /**
     * Launch a stream from API response data.
     * Creates synthetic NvComputer and NvApp objects from the response
     * and starts a streaming session.
     * 
     * @param response The stream launch response from the API
     * @param appName Display name of the application
     * @param appId Numeric ID of the application
     */
    Q_INVOKABLE void launchFromApiResponse(
        const AirPCStreamLaunchResponse& response,
        const QString& appName,
        int appId
    );
    
    /**
     * Check if a stream is currently active.
     */
    Q_INVOKABLE bool isStreamActive() const;

    /**
     * Get the current session for QML binding.
     */
    Q_INVOKABLE Session* currentSession() const;

signals:
    /**
     * Emitted when a stream has started successfully.
     */
    void streamStarted();

    /**
     * Emitted when a stream session is ready (for QML to take ownership).
     * @param appName Name of the application being streamed
     * @param session The created Session object
     */
    void sessionCreated(const QString& appName, Session* session);

    /**
     * Emitted when a stream ends.
     * @param reason Description of why the stream ended
     */
    void streamEnded(const QString& reason);

    /**
     * Emitted when a launch error occurs.
     * @param error Description of the error
     */
    void launchError(const QString& error);

private slots:
    void onSessionStageStarting(const QString& stage);
    void onSessionStageFailed(const QString& stage, int errorCode, const QString& failingPorts);
    void onSessionDisplayLaunchError(const QString& text);
    void onSessionFinished(int portTestResult);
    void onSessionReadyForDeletion();

private:
    /**
     * Create a synthetic NvComputer from API response data.
     * Sets up the computer with:
     * - activeAddress from streamHost:streamPort
     * - activeHttpsPort from response
     * - state = CS_ONLINE, pairState = PS_PAIRED
     * - API session token for authentication
     */
    NvComputer* createSyntheticComputer(const AirPCStreamLaunchResponse& response);

    /**
     * Create an NvApp with the given name and id.
     */
    NvApp createApp(const QString& name, int id);

    /**
     * Clean up the current session and synthetic computer.
     */
    void cleanup();

    Session* m_currentSession;
    NvComputer* m_syntheticComputer;
    QString m_currentAppName;
};

#endif // AIRPCSTREAMBRIDGE_H
