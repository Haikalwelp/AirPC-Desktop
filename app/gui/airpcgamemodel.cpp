#include "airpcgamemodel.h"

// ============================================================================
// AirPCGameModel Implementation
// ============================================================================

AirPCGameModel::AirPCGameModel(QObject* parent)
    : QAbstractListModel(parent)
    , m_api(AirPCApiClient::get())
    , m_streamBridge(AirPCStreamBridge::get())
{
    // Connect to API signals
    connect(m_api, &AirPCApiClient::appsLoaded, this, &AirPCGameModel::onAppsLoaded);
    connect(m_api, &AirPCApiClient::streamLaunched, this, &AirPCGameModel::onStreamLaunched);
    connect(m_api, &AirPCApiClient::streamLaunchFailed, this, &AirPCGameModel::onStreamLaunchFailed);
    connect(m_api, &AirPCApiClient::loadingChanged, this, &AirPCGameModel::loadingChanged);
    connect(m_api, &AirPCApiClient::errorOccurred, this, &AirPCGameModel::errorChanged);
    
    // Forward stream bridge signals to QML
    connect(m_streamBridge, &AirPCStreamBridge::streamStarted,
            this, &AirPCGameModel::streamStarted);
    connect(m_streamBridge, &AirPCStreamBridge::streamEnded,
            this, &AirPCGameModel::streamEnded);
    connect(m_streamBridge, &AirPCStreamBridge::launchError,
            this, &AirPCGameModel::streamError);
    connect(m_streamBridge, &AirPCStreamBridge::sessionCreated,
            this, &AirPCGameModel::sessionCreated);
}

int AirPCGameModel::rowCount(const QModelIndex& parent) const
{
    if (parent.isValid()) {
        return 0;
    }
    return m_games.size();
}

QVariant AirPCGameModel::data(const QModelIndex& index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_games.size()) {
        return QVariant();
    }

    const AirPCPublicApp& game = m_games[index.row()];

    switch (role) {
    case IdRole:
        return game.id;
    case TitleRole:
        return game.title;
    case UuidRole:
        return game.uuid;
    case ComputerNameRole:
        return game.computerName;
    case ComputerUuidRole:
        return game.computerUuid;
    case HostnameRole:
        return game.hostname;
    case PortRole:
        return game.port;
    case ImageUrlRole:
        return game.getImageUrl(m_api->authToken(), m_api->apiBaseUrl());
    case HdrSupportedRole:
        return game.hdrSupported;
    default:
        return QVariant();
    }
}

QHash<int, QByteArray> AirPCGameModel::roleNames() const
{
    QHash<int, QByteArray> roles;
    roles[IdRole] = "appId";
    roles[TitleRole] = "title";
    roles[UuidRole] = "appUuid";
    roles[ComputerNameRole] = "computerName";
    roles[ComputerUuidRole] = "computerUuid";
    roles[HostnameRole] = "hostname";
    roles[PortRole] = "port";
    roles[ImageUrlRole] = "imageUrl";
    roles[HdrSupportedRole] = "hdrSupported";
    return roles;
}

bool AirPCGameModel::loading() const
{
    return m_api->isLoading();
}

QString AirPCGameModel::errorMessage() const
{
    return m_api->errorMessage();
}

void AirPCGameModel::refresh()
{
    qInfo() << "AirPCGameModel: Refreshing game list...";
    m_api->fetchAllocations();
}

void AirPCGameModel::launchGame(int index)
{
    if (index < 0 || index >= m_games.size()) {
        qWarning() << "AirPCGameModel: Invalid game index:" << index;
        return;
    }

    const AirPCPublicApp& game = m_games[index];
    qInfo() << "AirPCGameModel: Launching game" << game.title << "on" << game.computerName;
    
    // Store pending launch info so we can retrieve app details when response arrives
    m_pendingLaunch.computerUuid = game.computerUuid;
    m_pendingLaunch.appId = game.id;
    m_pendingLaunch.appName = game.title;
    m_pendingLaunch.valid = true;
    
    m_api->launchStream(game.computerUuid, game.id, game.uuid);
}

void AirPCGameModel::launchGameById(const QString& computerUuid, const QString& appId)
{
    qInfo() << "AirPCGameModel: Launching game" << appId << "on computer" << computerUuid;

    // Find the UUID and name if we have it
    QString appUuid;
    QString appName = "Unknown App";
    for (const AirPCPublicApp& game : m_games) {
        if (game.computerUuid == computerUuid && game.id == appId) {
            appUuid = game.uuid;
            appName = game.title;
            break;
        }
    }

    // Store pending launch info so we can retrieve app details when response arrives
    m_pendingLaunch.computerUuid = computerUuid;
    m_pendingLaunch.appId = appId;
    m_pendingLaunch.appName = appName;
    m_pendingLaunch.valid = true;

    m_api->launchStream(computerUuid, appId, appUuid);
}

void AirPCGameModel::onAppsLoaded(const QList<AirPCPublicApp>& apps)
{
    qInfo() << "AirPCGameModel: Received" << apps.size() << "games";

    beginResetModel();
    m_games = apps;
    endResetModel();

    emit countChanged();
}

void AirPCGameModel::onStreamLaunched(const AirPCStreamLaunchResponse& response)
{
    qInfo() << "AirPCGameModel: Stream launch response received";
    
    // Priority for app info:
    // 1. From pending launch (fresh launch)
    // 2. From response itself (resume session - appId/appName populated from saved session)
    // 3. Fallback to "Unknown App"
    QString appName;
    int appId;
    
    if (m_pendingLaunch.valid) {
        // Fresh launch - use pending info
        appName = m_pendingLaunch.appName;
        appId = m_pendingLaunch.appId.toInt();
        m_pendingLaunch.valid = false;
        qInfo() << "AirPCGameModel: Using pending launch info";
    } else if (!response.appName.isEmpty()) {
        // Resume session - use info from response (populated from AirPCActiveSession)
        appName = response.appName;
        appId = response.appId.toInt();
        qInfo() << "AirPCGameModel: Using response app info (resume)";
    } else {
        // Fallback
        appName = "Unknown App";
        appId = 0;
        qWarning() << "AirPCGameModel: No app info available, using fallback";
    }
    
    qInfo() << "AirPCGameModel: Launching stream for" << appName << "(ID:" << appId << ")";
    
    // Launch via bridge - this will create the Session and start streaming
    m_streamBridge->launchFromApiResponse(response, appName, appId);
    
    // Also emit the legacy signal for backward compatibility
    emit gameLaunched(response.sessionId, response.streamHost, 
                      response.streamPort, response.streamHttpsPort);
}

void AirPCGameModel::onStreamLaunchFailed(const QString& error)
{
    qWarning() << "AirPCGameModel: Stream launch failed:" << error;
    emit launchFailed(error);
}

// ============================================================================
// AirPCGameSortFilterModel Implementation
// ============================================================================

AirPCGameSortFilterModel::AirPCGameSortFilterModel(QObject* parent)
    : QSortFilterProxyModel(parent)
{
    setFilterCaseSensitivity(Qt::CaseInsensitive);
    setSortRole(AirPCGameModel::TitleRole);
    sort(0);

    // Forward count changes
    connect(this, &QAbstractItemModel::rowsInserted, this, &AirPCGameSortFilterModel::countChanged);
    connect(this, &QAbstractItemModel::rowsRemoved, this, &AirPCGameSortFilterModel::countChanged);
    connect(this, &QAbstractItemModel::modelReset, this, &AirPCGameSortFilterModel::countChanged);
}

void AirPCGameSortFilterModel::setFilterText(const QString& text)
{
    if (m_filterText != text) {
        m_filterText = text;
        invalidateFilter();
        emit filterTextChanged();
        emit countChanged();
    }
}

bool AirPCGameSortFilterModel::filterAcceptsRow(int sourceRow, const QModelIndex& sourceParent) const
{
    if (m_filterText.isEmpty()) {
        return true;
    }

    QModelIndex index = sourceModel()->index(sourceRow, 0, sourceParent);
    QString title = sourceModel()->data(index, AirPCGameModel::TitleRole).toString();
    return title.contains(m_filterText, Qt::CaseInsensitive);
}

void AirPCGameSortFilterModel::launchGame(int index)
{
    // Map filtered index to source index
    QModelIndex proxyIndex = this->index(index, 0);
    QModelIndex sourceIndex = mapToSource(proxyIndex);

    if (sourceIndex.isValid()) {
        AirPCGameModel* sourceModel = qobject_cast<AirPCGameModel*>(this->sourceModel());
        if (sourceModel) {
            sourceModel->launchGame(sourceIndex.row());
        }
    }
}
