#include "BacklightController.h"
#include "SoundCheckController.h"
#include "UpdateController.h"
#include "UsbDeviceModel.h"

#include <QGuiApplication>
#include <QIcon>
#include <QDebug>
#include <QDir>
#include <QLocalServer>
#include <QLocalSocket>
#include <QLocale>
#include <QObject>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QStringList>
#include <QStandardPaths>
#include <QTranslator>
#include <QUrl>
#include <QWindow>

namespace
{
constexpr char INSTANCE_SERVER_NAME[] = "configuration";

QString instanceServerName()
{
    QString runtimePath = QStandardPaths::writableLocation(QStandardPaths::RuntimeLocation);
    if (runtimePath.isEmpty()) {
        runtimePath = QDir::tempPath();
    }
    QDir().mkpath(runtimePath);
    return QDir(runtimePath).filePath(QString::fromLatin1(INSTANCE_SERVER_NAME) + QStringLiteral(".sock"));
}

bool notifyExistingInstance(const QString &serverName, bool requestShow)
{
    QLocalSocket socket;
    socket.connectToServer(serverName, QIODeviceBase::WriteOnly);
    if (!socket.waitForConnected(150)) {
        QLocalServer::removeServer(serverName);
        return false;
    }

    if (requestShow) {
        socket.write("show\n");
        socket.flush();
        socket.waitForBytesWritten(150);
    }
    return true;
}

void showWindow(QObject *rootObject)
{
    auto *window = qobject_cast<QWindow *>(rootObject);
    if (!window) {
        return;
    }

    window->setFlag(Qt::FramelessWindowHint, true);
    window->showFullScreen();
    window->raise();
    window->requestActivate();
}
} // namespace

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    const bool backgroundMode = app.arguments().contains(QStringLiteral("--background"));

    QTranslator translator;
    if (QLocale().language() == QLocale::Chinese && translator.load(QStringLiteral(":/i18n/configuration_zh_CN.qm"))) {
        app.installTranslator(&translator);
    }

    QGuiApplication::setApplicationName(QCoreApplication::translate("Main", "Configuration"));
    QGuiApplication::setDesktopFileName(QStringLiteral("configuration"));
    QGuiApplication::setOrganizationName(QStringLiteral("NixOS Images"));
    QGuiApplication::setQuitOnLastWindowClosed(false);
    QIcon::setThemeName(QStringLiteral("breeze"));

    const QString serverName = instanceServerName();
    if (notifyExistingInstance(serverName, !backgroundMode)) {
        return 0;
    }

    QObject *rootObject = nullptr;
    bool pendingShow = !backgroundMode;
    QLocalServer instanceServer;
    if (!instanceServer.listen(serverName)) {
        QLocalServer::removeServer(serverName);
        if (!instanceServer.listen(serverName)) {
            qWarning().noquote() << QStringLiteral("Failed to listen for configuration instance requests:")
                                 << instanceServer.errorString();
        }
    }
    if (backgroundMode && !instanceServer.isListening()) {
        return 1;
    }
    QObject::connect(&instanceServer, &QLocalServer::newConnection, &app, [&instanceServer, &rootObject, &pendingShow] {
        while (QLocalSocket *client = instanceServer.nextPendingConnection()) {
            QObject::connect(client, &QLocalSocket::readyRead, client, [client, &rootObject, &pendingShow] {
                if (client->readAll().trimmed() == QByteArrayLiteral("show")) {
                    if (rootObject) {
                        showWindow(rootObject);
                    } else {
                        pendingShow = true;
                    }
                }
                client->disconnectFromServer();
            });
            QObject::connect(client, &QLocalSocket::disconnected, client, &QObject::deleteLater);
        }
    });

    BacklightController backlightController;
    UsbDeviceModel usbDeviceModel;
    SoundCheckController soundCheckController;
    UpdateController updateController;

    QQmlApplicationEngine engine;
    QObject::connect(&engine, &QQmlApplicationEngine::warnings, &app, [](const QList<QQmlError> &warnings) {
        for (const QQmlError &warning : warnings) {
            qWarning().noquote() << warning.toString();
        }
    });
    engine.rootContext()->setContextProperty(QStringLiteral("backlight"), &backlightController);
    engine.rootContext()->setContextProperty(QStringLiteral("usbDevices"), &usbDeviceModel);
    engine.rootContext()->setContextProperty(QStringLiteral("sound"), &soundCheckController);
    engine.rootContext()->setContextProperty(QStringLiteral("updates"), &updateController);

    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        [] {
            QCoreApplication::exit(-1);
        },
        Qt::QueuedConnection);

    engine.load(QUrl(QStringLiteral("qrc:/qt/qml/Configuration/Main.qml")));
    rootObject = engine.rootObjects().isEmpty() ? nullptr : engine.rootObjects().constFirst();
    if (pendingShow) {
        showWindow(rootObject);
    }

    return app.exec();
}
