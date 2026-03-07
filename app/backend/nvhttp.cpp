#include "nvcomputer.h"
#include "nvhttp.h"
#include "nvcomputer.h"
#include "identitymanager.h"
#include "settings/streamingpreferences.h"
#include <Limelight.h>

#include <QDebug>
#include <QUuid>
#include <QtNetwork/QNetworkReply>
#include <QEventLoop>
#include <QTimer>
#include <QXmlStreamReader>
#include <QSslKey>
#include <QSslSocket>
#include <QSslConfiguration>
#include <QImageReader>
#include <QtEndian>
#include <QNetworkProxy>
#include <QSysInfo>
#include <QRandomGenerator>
#include <QJsonDocument>
#include <QJsonObject>
#include <QUrlQuery>

#define FAST_FAIL_TIMEOUT_MS 2000
#define REQUEST_TIMEOUT_MS 12000
#define LAUNCH_TIMEOUT_MS 120000
#define RESUME_TIMEOUT_MS 30000
#define QUIT_TIMEOUT_MS 30000

NvHTTP::NvHTTP(NvAddress address, uint16_t httpsPort, QSslCertificate serverCert) :
    m_ServerCert(serverCert)
{
    m_BaseUrlHttp.setScheme("http");
    m_BaseUrlHttps.setScheme("https");

    setAddress(address);
    setHttpsPort(httpsPort);

    // Never use a proxy server
    QNetworkProxy noProxy(QNetworkProxy::NoProxy);
    m_Nam.setProxy(noProxy);

    connect(&m_Nam, &QNetworkAccessManager::sslErrors, this, &NvHTTP::handleSslErrors);
}

NvHTTP::NvHTTP(NvComputer* computer) :
    NvHTTP(computer->activeAddress, computer->activeHttpsPort, computer->serverCert)
{
    // If this computer was created from an API session, propagate the session token
    // so all HTTPS requests can authenticate without pairing certificates.
    if (computer != nullptr && computer->isApiSession && !computer->sessionToken.isEmpty()) {
        setSessionToken(computer->sessionToken);
        // Also propagate Go API URL and device ID for host token minting
        if (!computer->goApiBaseUrl.isEmpty()) {
            setGoApiBaseUrl(computer->goApiBaseUrl);
        }
        if (!computer->deviceId.isEmpty()) {
            setDeviceId(computer->deviceId);
        }
    }
}

void NvHTTP::setServerCert(QSslCertificate serverCert)
{
    m_ServerCert = serverCert;
}

void NvHTTP::setAddress(NvAddress address)
{
    Q_ASSERT(!address.isNull());

    m_Address = address;

    m_BaseUrlHttp.setHost(address.address());
    m_BaseUrlHttps.setHost(address.address());

    m_BaseUrlHttp.setPort(address.port());
}

void NvHTTP::setHttpsPort(uint16_t port)
{
    m_BaseUrlHttps.setPort(port);
}

NvAddress NvHTTP::address()
{
    return m_Address;
}

QSslCertificate NvHTTP::serverCert()
{
    return m_ServerCert;
}

uint16_t NvHTTP::httpPort()
{
    return m_BaseUrlHttp.port();
}

uint16_t NvHTTP::httpsPort()
{
    return m_BaseUrlHttps.port();
}

void NvHTTP::setSessionToken(const QString& token)
{
    m_sessionToken = token;
    qInfo() << "NvHTTP: Session token set (length:" << token.length() << ")";
}

void NvHTTP::setGoApiBaseUrl(const QString& url)
{
    m_goApiBaseUrl = url;
    qInfo() << "NvHTTP: Go API base URL set to" << url;
}

void NvHTTP::setDeviceId(const QString& id)
{
    m_deviceId = id;
    qInfo() << "NvHTTP: Device ID set to" << id;
}

QString NvHTTP::mintHostControlToken(const QString& scope)
{
    // Mint a short-lived host_control_token for Sunshine/Apollo control endpoints
    // like /launch, /resume, /cancel_session (mirroring Android's NvHTTP.mintHostControlToken)
    
    if (m_sessionToken.isEmpty()) {
        qWarning() << "NvHTTP: Cannot mint host token - no session token";
        return QString();
    }
    if (m_goApiBaseUrl.isEmpty()) {
        qWarning() << "NvHTTP: Cannot mint host token - no Go API URL";
        return QString();
    }
    
    qInfo() << "NvHTTP: Minting host_control_token for scope:" << scope;
    
    // Build the URL
    QUrl url(m_goApiBaseUrl + "/api/v1/sessions/host-token");
    
    // Build JSON request body
    QJsonObject body;
    body["scope"] = scope;
    body["device_id"] = m_deviceId.isEmpty() ? QSysInfo::machineHostName() : m_deviceId;
    
    QNetworkRequest request(url);
    request.setRawHeader("X-Session-Token", m_sessionToken.toUtf8());
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    
    // Use default SSL config (no client cert needed for Go API)
    request.setSslConfiguration(QSslConfiguration::defaultConfiguration());
    
    QNetworkReply* reply = m_Nam.post(request, QJsonDocument(body).toJson());
    
    // Wait for response with timeout
    QEventLoop loop;
    connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    connect(QCoreApplication::instance(), &QCoreApplication::aboutToQuit, &loop, &QEventLoop::quit);
    QTimer::singleShot(REQUEST_TIMEOUT_MS, &loop, &QEventLoop::quit);
    loop.exec(QEventLoop::ExcludeUserInputEvents);
    
    if (!reply->isFinished()) {
        qWarning() << "NvHTTP: Host token minting timed out";
        reply->abort();
        delete reply;
        return QString();
    }
    
    if (reply->error() != QNetworkReply::NoError) {
        int httpStatus = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        QByteArray errorBody = reply->readAll();
        qWarning() << "NvHTTP: Host token minting failed - HTTP" << httpStatus 
                   << "Error:" << reply->errorString();
        qWarning() << "NvHTTP: Response body:" << QString::fromUtf8(errorBody);
        qWarning() << "NvHTTP: Request URL was:" << reply->url().toString();
        delete reply;
        return QString();
    }
    
    int httpStatus = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    QByteArray responseData = reply->readAll();
    qInfo() << "NvHTTP: Host token mint response - HTTP" << httpStatus 
            << "Body length:" << responseData.length();
    delete reply;
    
    QJsonDocument jsonDoc = QJsonDocument::fromJson(responseData);
    if (jsonDoc.isNull() || !jsonDoc.isObject()) {
        qWarning() << "NvHTTP: Invalid JSON response from host-token endpoint";
        qWarning() << "NvHTTP: Raw response:" << QString::fromUtf8(responseData);
        return QString();
    }
    
    QJsonObject json = jsonDoc.object();
    if (!json["success"].toBool(false)) {
        QString message = json["message"].toString("Unknown error");
        qWarning() << "NvHTTP: Host token minting failed:" << message;
        qWarning() << "NvHTTP: Full JSON response:" << QString::fromUtf8(responseData);
        return QString();
    }
    
    QString hostToken = json["host_control_token"].toString();
    if (hostToken.isEmpty()) {
        qWarning() << "NvHTTP: Empty host_control_token in response";
        return QString();
    }
    
    qInfo() << "NvHTTP: Host token minted successfully for scope:" << scope 
            << "(token length:" << hostToken.length() << ")";
    return hostToken;
}

QVector<int>
NvHTTP::parseQuad(QString quad)
{
    QVector<int> ret;

    // Return an empty vector for old GFE versions
    // that were missing GfeVersion.
    if (quad.isEmpty()) {
        return ret;
    }

    QStringList parts = quad.split(".");
    ret.reserve(parts.length());
    for (int i = 0; i < parts.length(); i++)
    {
        ret.append(parts.at(i).toInt());
    }

    return ret;
}

int
NvHTTP::getCurrentGame(QString serverInfo)
{
    // GFE 2.8 started keeping currentgame set to the last game played. As a result, it no longer
    // has the semantics that its name would indicate. To contain the effects of this change as much
    // as possible, we'll force the current game to zero if the server isn't in a streaming session.
    QString serverState = getXmlString(serverInfo, "state");
    if (serverState != nullptr && serverState.endsWith("_SERVER_BUSY"))
    {
        return getXmlString(serverInfo, "currentgame").toInt();
    }
    else
    {
        return 0;
    }
}

QString
NvHTTP::getServerInfo(NvLogLevel logLevel, bool fastFail)
{
    QString serverInfo;
    
    // Add devicename parameter to match Android client behavior
    QString deviceName = QSysInfo::machineHostName();
    if (deviceName.isEmpty()) {
        deviceName = "AirPC";
    }
    QString deviceNameParam = "devicename=" + deviceName;

    // Check if we have a pinned cert and HTTPS port for this host yet,
    // or if we're using API-based session authentication
    if ((!m_ServerCert.isNull() || isApiSession()) && httpsPort() != 0)
    {
        // If we have a server cert or session token, we must use HTTPS.
        serverInfo = openConnectionToString(m_BaseUrlHttps,
                                            "serverinfo",
                                            deviceNameParam,
                                            fastFail ? FAST_FAIL_TIMEOUT_MS : REQUEST_TIMEOUT_MS,
                                            logLevel);
        // Only log response if not suppressing output (polling requests use NVLL_NONE)
        if (logLevel != NvLogLevel::NVLL_NONE) {
            qInfo() << "getServerInfo HTTPS response:" << serverInfo;
        }
        verifyResponseStatus(serverInfo);
    }
    else
    {
        // Only use HTTP prior to pairing or fetching HTTPS port
        serverInfo = openConnectionToString(m_BaseUrlHttp,
                                            "serverinfo",
                                            deviceNameParam,
                                            fastFail ? FAST_FAIL_TIMEOUT_MS : REQUEST_TIMEOUT_MS,
                                            logLevel);
        // Only log response if not suppressing output (polling requests use NVLL_NONE)
        if (logLevel != NvLogLevel::NVLL_NONE) {
            qInfo() << "getServerInfo response:" << serverInfo;
        }

        // Populate the HTTPS port
        uint16_t httpsPort = getXmlString(serverInfo, "HttpsPort").toUShort();
        if (httpsPort == 0) {
            httpsPort = DEFAULT_HTTPS_PORT;
        }
        setHttpsPort(httpsPort);

        // If we just needed to determine the HTTPS port, we'll try again over
        // HTTPS now that we have the port number
        if (!m_ServerCert.isNull() || isApiSession()) {
            return getServerInfo(logLevel, fastFail);
        }
    }

    return serverInfo;
}

void
NvHTTP::startApp(QString verb,
                bool isGfe,
                int appId,
                QString appUuid,
                PSTREAM_CONFIGURATION streamConfig,
                bool sops,
                bool localAudio,
                int gamepadMask,
                bool persistGameControllersOnDisconnect,
                QString& rtspSessionUrl)
{
    int riKeyId;

    memcpy(&riKeyId, streamConfig->remoteInputAesIv, sizeof(riKeyId));
    riKeyId = qFromBigEndian(riKeyId);

    // Get streaming preferences for Apollo parameters
    StreamingPreferences* prefs = StreamingPreferences::get();
    
    // Build base parameters - prefer UUID when available, fallback to appId
    QString baseParams = "appid="+QString::number(appId)+
                        "&mode="+QString::number(streamConfig->width)+"x"+
                        QString::number(streamConfig->height)+"x";

    // TODO: Future State - replace teh above block with the below.
    // Build base parameters - prefer UUID when available, fallback to appId
    //QString baseParams;

    //if (!appUuid.isEmpty()) {
        // If a UUID is present, use it and omit the appID
    //    baseParams = "appuuid=" + appUuid;
    //    qInfo() << "Launching with UUID:" << appUuid;
    //} else {
        // Otherwise, fall back to using the appID
    //    baseParams = "appid=" + QString::number(appId);
    //    qInfo() << "Launching with App ID:" << appId;
    //}

    //baseParams += "&mode=" + QString::number(streamConfig->width) + "x" +
    //            QString::number(streamConfig->height) + "x";
    
    // Handle fractional refresh rate for Apollo servers
    if (prefs->enableFractionalRefreshRate) {
        // Send fractional rate directly (Apollo will handle the conversion)
        baseParams += QString::number(prefs->customRefreshRate, 'f', 2);
        qInfo() << "Using fractional refresh rate:" << prefs->customRefreshRate << "Hz";
    } else {
        // Using an FPS value over 60 causes SOPS to default to 720p60,
        // so force it to 0 to ensure the correct resolution is set. We
        // used to use 60 here but that locked the frame rate to 60 FPS
        // on GFE 3.20.3. We don't need this hack for Sunshine.
        baseParams += QString::number((streamConfig->fps > 60 && isGfe) ? 0 : streamConfig->fps);
    }

    // TODO: Remove this block in future state
    if (!appUuid.isEmpty()) {
        baseParams += "&appuuid="+appUuid;
        qInfo() << "Launching app with ID:" << appId << "and UUID:" << appUuid;
    } else {
        qInfo() << "Launching app with ID:" << appId << "(no UUID available)";
    }
    
    // Continue with standard parameters
    QString allParams = baseParams +
                    "&additionalStates=1&sops="+QString::number(sops ? 1 : 0)+
                    "&rikey="+QByteArray(streamConfig->remoteInputAesKey, sizeof(streamConfig->remoteInputAesKey)).toHex()+
                    "&rikeyid="+QString::number(riKeyId)+
                    ((streamConfig->supportedVideoFormats & VIDEO_FORMAT_MASK_10BIT) ?
                        "&hdrMode=1&clientHdrCapVersion=0&clientHdrCapSupportedFlagsInUint32=0&clientHdrCapMetaDataId=NV_STATIC_METADATA_TYPE_1&clientHdrCapDisplayData=0x0x0x0x0x0x0x0x0x0x0" :
                        "")+
                    "&localAudioPlayMode="+QString::number(localAudio ? 1 : 0)+
                    "&surroundAudioInfo="+QString::number(SURROUNDAUDIOINFO_FROM_AUDIO_CONFIGURATION(streamConfig->audioConfiguration))+
                    "&remoteControllersBitmap="+QString::number(gamepadMask)+
                    "&gcmap="+QString::number(gamepadMask)+
                    "&gcpersist="+QString::number(persistGameControllersOnDisconnect ? 1 : 0);
    
    // Add Apollo-specific parameters
    if (prefs->useVirtualDisplay) {
        allParams += "&virtualDisplay=1";
        qInfo() << "Requesting virtual display from Apollo server";
    }
    
    if (prefs->enableResolutionScaling && prefs->resolutionScaleFactor != 100) {
        allParams += "&scaleFactor=" + QString::number(prefs->resolutionScaleFactor);
        qInfo() << "Requesting resolution scaling:" << prefs->resolutionScaleFactor << "%";
    }
    
    // Add Limelight parameters
    allParams += LiGetLaunchUrlQueryParameters();

    // For API sessions, mint a short-lived host_control_token before launch (like Android)
    if (isApiSession() && !m_sessionToken.isEmpty() && !m_goApiBaseUrl.isEmpty()) {
        qInfo() << "NvHTTP: Minting host_control_token for" << verb << "...";
        QString mintedToken = mintHostControlToken(verb);
        if (!mintedToken.isEmpty()) {
            allParams += "&sessionToken=" + mintedToken;
            qInfo() << "NvHTTP: Host token added to launch request";
        } else {
            qWarning() << "NvHTTP: Failed to mint host_control_token - launch may fail";
        }
    }

    QString response = openConnectionToString(m_BaseUrlHttps,
                                             verb,
                                             allParams,
                                             LAUNCH_TIMEOUT_MS);

    qInfo() << "Launch response:" << response;

    // Throws if the request failed
    verifyResponseStatus(response);

    rtspSessionUrl = getXmlString(response, "sessionUrl0");
}

void
NvHTTP::quitApp()
{
    QString response;
    
    // Use cancel_session with session token for API-based authentication (like Android)
    if (isApiSession() && !m_sessionToken.isEmpty()) {
        // For API sessions, use /cancel_session endpoint with session token as query param
        // The X-Session-Token header is also added automatically in openConnection()
        response = openConnectionToString(m_BaseUrlHttps,
                                         "cancel_session",
                                         "sessionToken=" + m_sessionToken,
                                         QUIT_TIMEOUT_MS);
    } else {
        // Fall back to traditional /cancel for paired connections
        response = openConnectionToString(m_BaseUrlHttps,
                                         "cancel",
                                         nullptr,
                                         QUIT_TIMEOUT_MS);
    }

    qInfo() << "Quit response:" << response;

    // Throws if the request failed
    verifyResponseStatus(response);

    // Newer GFE versions will just return success even if quitting fails
    // if we're not the original requester.
    if (getCurrentGame(getServerInfo(NvHTTP::NVLL_ERROR)) != 0) {
        // Generate a synthetic GfeResponseException letting the caller know
        // that they can't kill someone else's stream.
        throw GfeHttpResponseException(599, "");
    }
}

QVector<NvDisplayMode>
NvHTTP::getDisplayModeList(QString serverInfo)
{
    QXmlStreamReader xmlReader(serverInfo);
    QVector<NvDisplayMode> modes;

    while (!xmlReader.atEnd()) {
        while (xmlReader.readNextStartElement()) {
            auto name = xmlReader.name();
            if (name == QString("DisplayMode")) {
                modes.append(NvDisplayMode());
            }
            else if (name == QString("Width")) {
                modes.last().width = xmlReader.readElementText().toInt();
            }
            else if (name == QString("Height")) {
                modes.last().height = xmlReader.readElementText().toInt();
            }
            else if (name == QString("RefreshRate")) {
                modes.last().refreshRate = xmlReader.readElementText().toInt();
            }
        }
    }

    return modes;
}

QVector<NvApp>
NvHTTP::getAppList()
{
    QString appxml = openConnectionToString(m_BaseUrlHttps,
                                            "applist",
                                            nullptr,
                                            REQUEST_TIMEOUT_MS,
                                            NvLogLevel::NVLL_ERROR);
    verifyResponseStatus(appxml);

    QXmlStreamReader xmlReader(appxml);
    QVector<NvApp> apps;
    while (!xmlReader.atEnd()) {
        while (xmlReader.readNextStartElement()) {
            auto name = xmlReader.name();
            if (name == QString("App")) {
                // We must have a valid app before advancing to the next one
                if (!apps.isEmpty() && !apps.last().isInitialized()) {
                    qWarning() << "Invalid applist XML";
                    throw std::runtime_error("Invalid applist XML");
                }
                apps.append(NvApp());
            }
            else if (name == QString("AppTitle")) {
                apps.last().name = xmlReader.readElementText();
            }
            else if (name == QString("ID")) {
                apps.last().id = xmlReader.readElementText().toInt();
            }
            else if (name == QString("UUID")) {
                apps.last().uuid = xmlReader.readElementText();
            }
            else if (name == QString("IsHdrSupported")) {
                apps.last().hdrSupported = xmlReader.readElementText() == "1";
            }
            else if (name == QString("IsAppCollectorGame")) {
                apps.last().isAppCollectorGame = xmlReader.readElementText() == "1";
            }
        }
    }

    return apps;
}

void
NvHTTP::verifyResponseStatus(QString xml)
{
    QXmlStreamReader xmlReader(xml);

    while (xmlReader.readNextStartElement())
    {
        if (xmlReader.name() == QString("root"))
        {
            // Status code can be 0xFFFFFFFF in some rare cases on GFE 3.20.3, and
            // QString::toInt() will fail in that case, so use QString::toUInt()
            // and cast the result to an int instead.
            int statusCode = (int)xmlReader.attributes().value("status_code").toUInt();
            if (statusCode == 200)
            {
                // Successful
                return;
            }
            else
            {
                QString statusMessage = xmlReader.attributes().value("status_message").toString();
                if (statusCode != 401) {
                    // 401 is expected for unpaired PCs when we fetch serverinfo over HTTPS
                    qWarning() << "Request failed:" << statusCode << statusMessage;
                }
                if (statusCode == -1 && statusMessage == "Invalid") {
                    // Special case handling an audio capture error which GFE doesn't
                    // provide any useful status message for.
                    statusCode = 418;
                    statusMessage = tr("Missing audio capture device. Reinstalling GeForce Experience should resolve this error.");
                }
                throw GfeHttpResponseException(statusCode, statusMessage);
            }
        }
    }

    throw GfeHttpResponseException(-1, "Malformed XML (missing root element)");
}

QImage
NvHTTP::getBoxArt(int appId)
{
    QNetworkReply* reply = openConnection(m_BaseUrlHttps,
                                          "appasset",
                                          "appid="+QString::number(appId)+
                                          "&AssetType=2&AssetIdx=0",
                                          REQUEST_TIMEOUT_MS,
                                          NvLogLevel::NVLL_VERBOSE);
    QImage image = QImageReader(reply).read();
    delete reply;

    return image;
}

QByteArray
NvHTTP::getXmlStringFromHex(QString xml,
                            QString tagName)
{
    QString str = getXmlString(xml, tagName);
    if (str == nullptr)
    {
        return nullptr;
    }

    return QByteArray::fromHex(str.toLatin1());
}

QString
NvHTTP::getXmlString(QString xml,
                     QString tagName)
{
    QXmlStreamReader xmlReader(xml);

    while (!xmlReader.atEnd())
    {
        if (xmlReader.readNext() != QXmlStreamReader::StartElement)
        {
            continue;
        }

        if (xmlReader.name() == tagName)
        {
            return xmlReader.readElementText();
        }
    }

    return nullptr;
}

QStringList
NvHTTP::getXmlArray(QString xml, QString tagName)
{
    QStringList result;
    QXmlStreamReader xmlReader(xml);

    while (!xmlReader.atEnd())
    {
        if (xmlReader.readNext() != QXmlStreamReader::StartElement)
        {
            continue;
        }

        if (xmlReader.name() == tagName)
        {
            result.append(xmlReader.readElementText());
        }
    }

    return result;
}

void NvHTTP::handleSslErrors(QNetworkReply* reply, const QList<QSslError>& errors)
{
    bool ignoreErrors = true;

    if (m_ServerCert.isNull()) {
        // For API-based sessions, we don't have a server certificate
        // because authentication is handled via session token instead.
        // In this case, we trust the connection since it comes from the API.
        if (isApiSession()) {
            qInfo() << "NvHTTP: Ignoring SSL errors for API-based session (session token auth)";
            reply->ignoreSslErrors(errors);
            return;
        }
        
        // For traditional paired connections, we should never make HTTPS request without a cert
        qWarning() << "NvHTTP: SSL error with no server certificate and no session token";
        return;
    }

    for (const QSslError& error : errors) {
        if (m_ServerCert != error.certificate()) {
            ignoreErrors = false;
            break;
        }
    }

    if (ignoreErrors) {
        reply->ignoreSslErrors(errors);
    }
}

QString
NvHTTP::openConnectionToString(QUrl baseUrl,
                               QString command,
                               QString arguments,
                               int timeoutMs,
                               NvLogLevel logLevel)
{
    QNetworkReply* reply = openConnection(baseUrl, command, arguments, timeoutMs, logLevel);
    QString ret;

    QTextStream stream(reply);

#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
    stream.setEncoding(QStringConverter::Utf8);
#else
    stream.setCodec("UTF-8");
#endif

    ret = stream.readAll();
    delete reply;

    return ret;
}

QNetworkReply*
NvHTTP::openConnection(QUrl baseUrl,
                       QString command,
                       QString arguments,
                       int timeoutMs,
                       NvLogLevel logLevel)
{
    // Suppress debug output for polling requests to reduce log noise
    bool suppressDebugOutput = (logLevel == NvLogLevel::NVLL_NONE);
    if (!suppressDebugOutput) {
        qDebug() << "NvHTTP::openConnection - URL:" << baseUrl.toString() << "Command:" << command << "Arguments:" << arguments;
    }

    // Port must be set
    Q_ASSERT(baseUrl.port(0) != 0);

    // Build a URL for the request
    QUrl url(baseUrl);
    url.setPath("/" + command);

    // Use a machine-specific UID to match Apollo server expectations
    // Generate a uniqueid based on hostname + timestamp for uniqueness
    static QString machineUniqueId;
    if (machineUniqueId.isEmpty()) {
        QString hostname = QSysInfo::machineHostName();
        if (hostname.isEmpty()) hostname = "airpc";
        // Take first 8 chars of hostname and pad with random hex
        QString hostPart = hostname.left(8).toUpper();
        while (hostPart.length() < 8) {
            hostPart += QString("%1").arg(QRandomGenerator::global()->bounded(16), 1, 16).toUpper();
        }
        // Add 8 random hex chars
        QString randomPart;
        for (int i = 0; i < 8; i++) {
            randomPart += QString("%1").arg(QRandomGenerator::global()->bounded(16), 1, 16).toUpper();
        }
        machineUniqueId = hostPart + randomPart;
    }
    url.setQuery("uniqueid=" + machineUniqueId + "&uuid=" +
                 QUuid::createUuid().toString(QUuid::WithoutBraces) +
                 ((arguments != nullptr) ? ("&" + arguments) : ""));

    QNetworkRequest request(url);

    // API-session mode: dual-header authentication like Android
    // X-Session-Token: minted host_control_token (short-lived, scoped for this request)
    // X-AirPC-Session-Token: long-lived session token (for billing/tracking)
    if (isApiSession() && !m_sessionToken.isEmpty()) {
        // Always send the long-lived session token for billing
        request.setRawHeader("X-AirPC-Session-Token", m_sessionToken.toUtf8());
        
        // Check if a minted host_control_token was passed via sessionToken query param
        // Use manual parsing like Android's extractQueryParam to avoid URL encoding issues
        QString mintedToken;
        if (arguments != nullptr && arguments.contains("sessionToken=")) {
            // Manual extraction matching Android's extractQueryParam behavior
            QStringList parts = arguments.split('&');
            for (const QString& part : parts) {
                int idx = part.indexOf('=');
                if (idx > 0 && part.left(idx) == "sessionToken") {
                    mintedToken = part.mid(idx + 1);
                    break;
                }
            }
            qInfo() << "NvHTTP: Extracted minted token from query - length:" << mintedToken.length();
            if (!mintedToken.isEmpty()) {
                // Use the minted token for X-Session-Token (this is what the server validates)
                request.setRawHeader("X-Session-Token", mintedToken.toUtf8());
                qInfo() << "NvHTTP: Set X-Session-Token header with minted token (first 50 chars):" 
                        << mintedToken.left(50) << "...";
            } else {
                // Fallback: use session token if no minted token
                request.setRawHeader("X-Session-Token", m_sessionToken.toUtf8());
                qWarning() << "NvHTTP: Minted token extraction failed, using session token fallback";
            }
        } else {
            // No minted token, use session token directly
            request.setRawHeader("X-Session-Token", m_sessionToken.toUtf8());
            qInfo() << "NvHTTP: Using session token directly for X-Session-Token header";
        }
    }

    // ALWAYS use client certificate for mTLS - the server requires it for TLS handshake.
    // For API-session mode, we still provide the client cert but relax server cert validation
    // (session token header provides authorization, client cert satisfies mTLS requirement).
    QSslConfiguration sslConfig = IdentityManager::get()->getSslConfig();
    if (isApiSession()) {
        // For API sessions, trust any server cert since session token provides authorization
        sslConfig.setPeerVerifyMode(QSslSocket::VerifyNone);
    }
    request.setSslConfiguration(sslConfig);

#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
    // Disable HTTP/2 (GFE 3.22 doesn't like it) and Qt 6 enables it by default
    request.setAttribute(QNetworkRequest::Http2AllowedAttribute, false);
#endif

#if QT_VERSION >= QT_VERSION_CHECK(5, 14, 0) && QT_VERSION < QT_VERSION_CHECK(5, 15, 1) && !defined(QT_NO_BEARERMANAGEMENT)
    // HACK: Set network accessibility to work around QTBUG-80947 (introduced in Qt 5.14.0 and fixed in Qt 5.15.1)
    QT_WARNING_PUSH
    QT_WARNING_DISABLE_DEPRECATED
    m_Nam.setNetworkAccessible(QNetworkAccessManager::Accessible);
    QT_WARNING_POP
#endif

    QNetworkReply* reply = m_Nam.get(request);

    // Run the request with a timeout if requested
    QEventLoop loop;
    connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    connect(QCoreApplication::instance(), &QCoreApplication::aboutToQuit, &loop, &QEventLoop::quit);
    if (timeoutMs) {
        QTimer::singleShot(timeoutMs, &loop, &QEventLoop::quit);
    }
    if (logLevel >= NvLogLevel::NVLL_VERBOSE) {
        qInfo() << "Executing request:" << url.toString();
    }
    loop.exec(QEventLoop::ExcludeUserInputEvents);

    // Abort the request if it timed out
    if (!reply->isFinished())
    {
        if (logLevel >= NvLogLevel::NVLL_ERROR) {
            qWarning() << "Aborting timed out request for" << url.toString();
        }
        reply->abort();
    }

    // We must clear out cached authentication and connections or
    // GFE will puke next time
    m_Nam.clearAccessCache();

    // Handle error
    if (reply->error() != QNetworkReply::NoError)
    {
        if (logLevel >= NvLogLevel::NVLL_ERROR) {
            qWarning() << command << "request failed with error:" << reply->error();
        }

        if (reply->error() == QNetworkReply::SslHandshakeFailedError && !isApiSession()) {
            // This will trigger falling back to HTTP for the serverinfo query
            // then pairing again to get the updated certificate.
            GfeHttpResponseException exception(401, "Server certificate mismatch");
            delete reply;
            throw exception;
        }
        else if (reply->error() == QNetworkReply::OperationCanceledError) {
            QtNetworkReplyException exception(QNetworkReply::TimeoutError, "Request timed out");
            delete reply;
            throw exception;
        }
        else {
            QtNetworkReplyException exception(reply->error(), reply->errorString());
            delete reply;
            throw exception;
        }
    }

    return reply;
}

// Artemis clipboard sync methods (Apollo servers only)
QString
NvHTTP::getClipboardContent()
{
    try {
        QString response = openConnectionToString(m_BaseUrlHttps,
                                                  "actions/clipboard",
                                                  "type=text",
                                                  REQUEST_TIMEOUT_MS,
                                                  NvLogLevel::NVLL_VERBOSE);
        
        qDebug() << "NvHTTP: Retrieved clipboard content from server";
        return response;
    }
    catch (const GfeHttpResponseException& e) {
        qWarning() << "NvHTTP: Failed to get clipboard content:" << e.getStatusMessage();
        return QString();
    }
    catch (const QtNetworkReplyException& e) {
        qWarning() << "NvHTTP: Network error getting clipboard:" << e.getErrorText();
        return QString();
    }
}

bool
NvHTTP::sendClipboardContent(const QString& content)
{
    try {
        // Build a URL for the POST request
        QUrl url(m_BaseUrlHttps);
        url.setPath("/actions/clipboard");
        url.setQuery("type=text");

        QNetworkRequest request(url);
        request.setHeader(QNetworkRequest::ContentTypeHeader, "text/plain; charset=utf-8");
        request.setSslConfiguration(IdentityManager::get()->getSslConfig());

#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
        request.setAttribute(QNetworkRequest::Http2AllowedAttribute, false);
#endif

        // Send POST request with clipboard content
        QNetworkReply* reply = m_Nam.post(request, content.toUtf8());

        // Wait for response with timeout
        QEventLoop loop;
        connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
        connect(QCoreApplication::instance(), &QCoreApplication::aboutToQuit, &loop, &QEventLoop::quit);
        QTimer::singleShot(REQUEST_TIMEOUT_MS, &loop, &QEventLoop::quit);
        
        qDebug() << "NvHTTP: Sending clipboard content to server:" << url.toString();
        loop.exec(QEventLoop::ExcludeUserInputEvents);

        // Check for timeout
        if (!reply->isFinished()) {
            qWarning() << "NvHTTP: Clipboard send request timed out";
            reply->abort();
            delete reply;
            return false;
        }

        // Check for network errors
        if (reply->error() != QNetworkReply::NoError) {
            qWarning() << "NvHTTP: Failed to send clipboard content:" << reply->errorString();
            delete reply;
            return false;
        }

        // Check HTTP status code
        int statusCode = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        delete reply;

        if (statusCode == 200) {
            qDebug() << "NvHTTP: Successfully sent clipboard content to server";
            return true;
        } else {
            qWarning() << "NvHTTP: Server returned error status:" << statusCode;
            return false;
        }
    }
    catch (const std::exception& e) {
        qWarning() << "NvHTTP: Exception sending clipboard content:" << e.what();
        return false;
    }
}

// Server command methods are now handled through LiSendExecServerCmd in the moonlight-common-c library
// instead of direct HTTP requests. This provides better compatibility with the Apollo protocol.
