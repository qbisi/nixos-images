#pragma once

#include <QObject>
#include <QProcess>
#include <QSocketNotifier>
#include <QString>
#include <QStringList>
#include <QTimer>

struct udev;
struct udev_monitor;

class UpdateController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString sourcePath READ sourcePath CONSTANT)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(QString log READ log NOTIFY logChanged)
    Q_PROPERTY(QString lastApplied READ lastApplied NOTIFY stateChanged)
    Q_PROPERTY(QString lastBoot READ lastBoot NOTIFY stateChanged)
    Q_PROPERTY(bool running READ running NOTIFY runningChanged)
    Q_PROPERTY(bool imageDetected READ imageDetected NOTIFY stateChanged)
    Q_PROPERTY(QStringList updateImages READ updateImages NOTIFY stateChanged)
    Q_PROPERTY(QStringList updateImageNames READ updateImageNames NOTIFY stateChanged)
    Q_PROPERTY(int selectedImage READ selectedImage WRITE setSelectedImage NOTIFY stateChanged)

public:
    explicit UpdateController(QObject *parent = nullptr);
    ~UpdateController() override;

    QString sourcePath() const;
    QString status() const;
    QString log() const;
    QString lastApplied() const;
    QString lastBoot() const;
    bool running() const;
    bool imageDetected() const;
    QStringList updateImages() const;
    QStringList updateImageNames() const;
    int selectedImage() const;
    void setSelectedImage(int selectedImage);

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void applyUpdate();
    Q_INVOKABLE void systemUpdate();
    Q_INVOKABLE void reboot();
    Q_INVOKABLE void shutdown();
    Q_INVOKABLE void clearLog();

Q_SIGNALS:
    void statusChanged();
    void logChanged();
    void stateChanged();
    void runningChanged();

private:
    void setupMonitor();
    void scheduleRefresh();
    void refreshState();
    void mountUsbStorage();
    bool isMounted(const QString &mountPoint) const;
    bool runMountCommand(const QString &device);
    QStringList usbStorageCandidates() const;
    QStringList findUpdateImages() const;
    QString selectedImagePath() const;
    void startUpdate(const QString &mode);
    void requestPowerAction(const QString &verb, const QString &requestedStatus, const QString &failedStatus);
    void appendLog(const QString &text);
    void setStatus(const QString &status);
    QString readTrimmed(const QString &path) const;
    QString systemdMountCommand() const;
    QString updateCommand() const;
    QString pkexecCommand() const;
    QString systemctlCommand() const;

    QString m_status;
    QString m_log;
    QString m_mountError;
    QString m_lastApplied;
    QString m_lastBoot;
    QStringList m_updateImages;
    int m_selectedImage = -1;
    bool m_imageDetected = false;
    QProcess m_process;
    udev *m_udev = nullptr;
    udev_monitor *m_monitor = nullptr;
    QSocketNotifier *m_notifier = nullptr;
    QTimer m_deviceRefreshTimer;
};
