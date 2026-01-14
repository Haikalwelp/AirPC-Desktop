#pragma once

#include "../backend/airpcapiclient.h"
#include "../backend/airpcstreambridge.h"

#include <QAbstractListModel>
#include <QSortFilterProxyModel>

// Forward declarations
class Session;

/**
 * QML-friendly model for AirPC public games.
 * Exposes game list from AirPCApiClient to QML views.
 * 
 * Provides:
 * - Roles for QML binding (title, id, computerName, imageUrl, etc.)
 * - Sorting and filtering via proxy model
 * - Automatic updates when API data changes
 */
class AirPCGameModel : public QAbstractListModel
{
    Q_OBJECT

    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY errorChanged)

public:
    enum Roles {
        IdRole = Qt::UserRole + 1,
        TitleRole,
        UuidRole,
        ComputerNameRole,
        ComputerUuidRole,
        HostnameRole,
        PortRole,
        ImageUrlRole,
        HdrSupportedRole
    };

    explicit AirPCGameModel(QObject* parent = nullptr);

    // QAbstractListModel interface
    int rowCount(const QModelIndex& parent = QModelIndex()) const override;
    QVariant data(const QModelIndex& index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    // Properties
    int count() const { return m_games.size(); }
    bool loading() const;
    QString errorMessage() const;

    // Actions
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void launchGame(int index);
    Q_INVOKABLE void launchGameById(const QString& computerUuid, const QString& appId);

signals:
    void countChanged();
    void loadingChanged();
    void errorChanged();
    void gameLaunched(const QString& sessionId, const QString& streamHost, int streamPort, int httpsPort);
    void launchFailed(const QString& error);
    
    // Stream bridge signals forwarded to QML
    void streamStarted();
    void streamEnded(const QString& reason);
    void streamError(const QString& error);
    void sessionCreated(const QString& appName, Session* session);

private slots:
    void onAppsLoaded(const QList<AirPCPublicApp>& apps);
    void onStreamLaunched(const AirPCStreamLaunchResponse& response);
    void onStreamLaunchFailed(const QString& error);

private:
    QList<AirPCPublicApp> m_games;
    AirPCApiClient* m_api;
    AirPCStreamBridge* m_streamBridge;
    
    // Track pending launch to retrieve app info when response arrives
    struct PendingLaunch {
        QString computerUuid;
        QString appId;
        QString appName;
        bool valid = false;
    };
    PendingLaunch m_pendingLaunch;
};

/**
 * Sortable/filterable proxy model for game list.
 * Use this in QML for search functionality.
 */
class AirPCGameSortFilterModel : public QSortFilterProxyModel
{
    Q_OBJECT

    Q_PROPERTY(QString filterText READ filterText WRITE setFilterText NOTIFY filterTextChanged)
    Q_PROPERTY(int count READ count NOTIFY countChanged)

public:
    explicit AirPCGameSortFilterModel(QObject* parent = nullptr);

    QString filterText() const { return m_filterText; }
    void setFilterText(const QString& text);
    int count() const { return rowCount(); }

    Q_INVOKABLE void launchGame(int index);

signals:
    void filterTextChanged();
    void countChanged();

protected:
    bool filterAcceptsRow(int sourceRow, const QModelIndex& sourceParent) const override;

private:
    QString m_filterText;
};
