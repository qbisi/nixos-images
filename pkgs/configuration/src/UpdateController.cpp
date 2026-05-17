#include "UpdateController.h"

#include <libudev.h>

#include <QDateTime>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QStandardPaths>
#include <QTimer>

#include <unistd.h>

#include <algorithm>

UpdateController::UpdateController(QObject *parent)
    : QObject(parent)
    , m_udev(udev_new())
{
    m_deviceRefreshTimer.setSingleShot(true);
    m_deviceRefreshTimer.setInterval(700);
    connect(&m_deviceRefreshTimer, &QTimer::timeout, this, &UpdateController::refresh);

    connect(&m_process, &QProcess::readyReadStandardOutput, this, [this] {
        appendLog(QString::fromLocal8Bit(m_process.readAllStandardOutput()));
    });
    connect(&m_process, &QProcess::readyReadStandardError, this, [this] {
        appendLog(QString::fromLocal8Bit(m_process.readAllStandardError()));
    });
    connect(&m_process, &QProcess::started, this, [this] {
        Q_EMIT runningChanged();
        setStatus(tr("Offline update running"));
    });
    connect(&m_process, qOverload<int, QProcess::ExitStatus>(&QProcess::finished), this, [this](int exitCode, QProcess::ExitStatus exitStatus) {
        Q_EMIT runningChanged();
        refresh();
        if (exitStatus == QProcess::NormalExit && exitCode == 0) {
            setStatus(tr("Offline update completed"));
        } else {
            setStatus(tr("Offline update failed with exit code %1").arg(exitCode));
        }
    });
    connect(&m_process, &QProcess::errorOccurred, this, [this](QProcess::ProcessError error) {
        Q_UNUSED(error)
        Q_EMIT runningChanged();
        setStatus(tr("Unable to start offline update: %1").arg(m_process.errorString()));
    });

    setupMonitor();
    QTimer::singleShot(300, this, &UpdateController::refreshState);
    QTimer::singleShot(5000, this, &UpdateController::refresh);
}

UpdateController::~UpdateController()
{
    if (m_notifier) {
        m_notifier->setEnabled(false);
    }
    if (m_monitor) {
        udev_monitor_unref(m_monitor);
    }
    if (m_udev) {
        udev_unref(m_udev);
    }
}

QString UpdateController::sourcePath() const
{
    return QStringLiteral("/mnt");
}

QString UpdateController::status() const
{
    return m_status;
}

QString UpdateController::log() const
{
    return m_log;
}

QString UpdateController::lastApplied() const
{
    return m_lastApplied;
}

QString UpdateController::lastBoot() const
{
    return m_lastBoot;
}

bool UpdateController::running() const
{
    return m_process.state() != QProcess::NotRunning;
}

bool UpdateController::imageDetected() const
{
    return m_imageDetected;
}

QStringList UpdateController::updateImages() const
{
    return m_updateImages;
}

QStringList UpdateController::updateImageNames() const
{
    QStringList names;
    names.reserve(m_updateImages.size());
    for (const QString &image : m_updateImages) {
        names.push_back(QFileInfo(image).fileName());
    }
    return names;
}

int UpdateController::selectedImage() const
{
    return m_selectedImage;
}

void UpdateController::setSelectedImage(int selectedImage)
{
    const int maxIndex = static_cast<int>(m_updateImages.size()) - 1;
    const int normalized = m_updateImages.isEmpty() ? -1 : std::clamp(selectedImage, 0, maxIndex);
    if (m_selectedImage == normalized) {
        return;
    }

    m_selectedImage = normalized;
    Q_EMIT stateChanged();
}

void UpdateController::refresh()
{
    mountUsbStorage();
    refreshState();
}

void UpdateController::setupMonitor()
{
    if (!m_udev) {
        return;
    }

    m_monitor = udev_monitor_new_from_netlink(m_udev, "udev");
    if (!m_monitor) {
        return;
    }

    udev_monitor_filter_add_match_subsystem_devtype(m_monitor, "block", nullptr);
    if (udev_monitor_enable_receiving(m_monitor) < 0) {
        udev_monitor_unref(m_monitor);
        m_monitor = nullptr;
        return;
    }

    const int fd = udev_monitor_get_fd(m_monitor);
    if (fd < 0) {
        return;
    }

    m_notifier = new QSocketNotifier(fd, QSocketNotifier::Read, this);
    connect(m_notifier, &QSocketNotifier::activated, this, [this] {
        bool storageChanged = false;
        while (udev_device *event = udev_monitor_receive_device(m_monitor)) {
            const char *devnode = udev_device_get_devnode(event);
            const char *sysname = udev_device_get_sysname(event);
            const bool sdDevnode = devnode && QString::fromUtf8(devnode).startsWith(QStringLiteral("/dev/sd"));
            const bool sdSysname = sysname && QString::fromUtf8(sysname).startsWith(QStringLiteral("sd"));
            if (sdDevnode || sdSysname) {
                storageChanged = true;
            }
            udev_device_unref(event);
        }

        if (storageChanged) {
            scheduleRefresh();
        }
    });
}

void UpdateController::scheduleRefresh()
{
    m_deviceRefreshTimer.start();
}

void UpdateController::refreshState()
{
    const QString previousApplied = m_lastApplied;
    const QString previousBoot = m_lastBoot;
    const QString previousSelectedImage = selectedImagePath();
    const QStringList previousUpdateImages = m_updateImages;
    const int previousSelectedImageIndex = m_selectedImage;
    const bool previousImageDetected = m_imageDetected;

    m_lastApplied = readTrimmed(QStringLiteral("/var/lib/offline-update/last-applied-at"));
    m_lastBoot = readTrimmed(QStringLiteral("/var/lib/offline-update/last-boot-at"));
    m_updateImages = findUpdateImages();
    m_imageDetected = !m_updateImages.isEmpty();

    if (m_updateImages.isEmpty()) {
        m_selectedImage = -1;
    } else {
        int selected = previousSelectedImage.isEmpty() ? -1 : m_updateImages.indexOf(previousSelectedImage);
        if (selected < 0) {
            const int maxIndex = static_cast<int>(m_updateImages.size()) - 1;
            selected = std::clamp(previousSelectedImageIndex, 0, maxIndex);
        }
        m_selectedImage = selected;
    }

    if (m_lastApplied != previousApplied || m_lastBoot != previousBoot || m_updateImages != previousUpdateImages
        || m_selectedImage != previousSelectedImageIndex || m_imageDetected != previousImageDetected) {
        Q_EMIT stateChanged();
    }

    if (!running()) {
        if (m_imageDetected) {
            setStatus(m_updateImages.size() == 1 ? tr("Update image detected") : tr("%1 update images detected").arg(m_updateImages.size()));
        } else if (!m_mountError.isEmpty()) {
            setStatus(m_mountError);
        } else {
            setStatus(tr("No *update.img under source path"));
        }
    }
}

void UpdateController::mountUsbStorage()
{
    m_mountError.clear();

    if (!findUpdateImages().isEmpty()) {
        return;
    }

    QDir().mkpath(sourcePath());
    if (isMounted(sourcePath())) {
        return;
    }

    const QStringList candidates = usbStorageCandidates();
    if (candidates.isEmpty()) {
        m_mountError = tr("No USB storage device found");
        return;
    }

    appendLog(QStringLiteral("\n[%1] USB update media candidates: %2\n")
                  .arg(QDateTime::currentDateTime().toString(Qt::ISODate), candidates.join(QStringLiteral(", "))));

    for (const QString &candidate : candidates) {
        if (runMountCommand(candidate)) {
            if (!findUpdateImages().isEmpty()) {
                setStatus(tr("Mounted USB update media"));
            }
            return;
        }
    }

    if (m_mountError.isEmpty()) {
        m_mountError = tr("Unable to mount USB update media");
    }
}

bool UpdateController::isMounted(const QString &mountPoint) const
{
    QFile file(QStringLiteral("/proc/self/mountinfo"));
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return false;
    }

    while (!file.atEnd()) {
        const QList<QByteArray> fields = file.readLine().simplified().split(' ');
        if (fields.size() > 4 && QString::fromUtf8(fields.at(4)) == mountPoint) {
            return true;
        }
    }

    return false;
}

bool UpdateController::runMountCommand(const QString &device)
{
    const QString command = systemdMountCommand();
    if (command.isEmpty()) {
        m_mountError = tr("systemd-mount command not found");
        return false;
    }

    appendLog(QStringLiteral("[%1] %2 --collect --no-ask-password -o ro %3 %4\n")
                  .arg(QDateTime::currentDateTime().toString(Qt::ISODate), command, device, sourcePath()));

    QProcess process;
    process.setProgram(command);
    process.setArguments({
        QStringLiteral("--collect"),
        QStringLiteral("--no-ask-password"),
        QStringLiteral("-o"),
        QStringLiteral("ro"),
        device,
        sourcePath(),
    });

    process.start();
    if (!process.waitForStarted(1000)) {
        m_mountError = tr("Unable to start systemd-mount: %1").arg(process.errorString());
        appendLog(QStringLiteral("mount start failed: %1\n").arg(process.errorString()));
        return false;
    }

    if (!process.waitForFinished(5000)) {
        process.kill();
        process.waitForFinished(1000);
        m_mountError = tr("Mount timed out for %1").arg(device);
        appendLog(QStringLiteral("mount timed out for %1\n").arg(device));
        return false;
    }

    const QString output = QString::fromLocal8Bit(process.readAllStandardOutput()) + QString::fromLocal8Bit(process.readAllStandardError());
    if (!output.trimmed().isEmpty()) {
        appendLog(output.endsWith(QLatin1Char('\n')) ? output : output + QLatin1Char('\n'));
    }

    const bool ok = process.exitStatus() == QProcess::NormalExit && process.exitCode() == 0;
    if (!ok) {
        m_mountError = tr("Mount failed for %1").arg(device);
    }

    return ok;
}

QStringList UpdateController::usbStorageCandidates() const
{
    if (!m_udev) {
        return {};
    }

    QStringList partitions;
    QStringList filesystemDisks;
    QStringList otherDisks;

    udev_enumerate *enumerate = udev_enumerate_new(m_udev);
    if (!enumerate) {
        return {};
    }

    udev_enumerate_add_match_subsystem(enumerate, "block");
    udev_enumerate_scan_devices(enumerate);

    udev_list_entry *entries = udev_enumerate_get_list_entry(enumerate);
    udev_list_entry *entry = nullptr;
    udev_list_entry_foreach(entry, entries)
    {
        const char *path = udev_list_entry_get_name(entry);
        if (!path) {
            continue;
        }

        udev_device *device = udev_device_new_from_syspath(m_udev, path);
        if (!device) {
            continue;
        }

        const QString sysname = QString::fromUtf8(udev_device_get_sysname(device) ? udev_device_get_sysname(device) : "");
        if (!sysname.startsWith(QStringLiteral("sd"))) {
            udev_device_unref(device);
            continue;
        }

        QString devnode = QString::fromUtf8(udev_device_get_devnode(device) ? udev_device_get_devnode(device) : "");
        if (devnode.isEmpty()) {
            const char *propertyDevname = udev_device_get_property_value(device, "DEVNAME");
            devnode = propertyDevname ? QString::fromUtf8(propertyDevname) : QString();
        }
        if (devnode.isEmpty()) {
            devnode = QStringLiteral("/dev/") + sysname;
        }

        const QString devtype = QString::fromUtf8(udev_device_get_devtype(device) ? udev_device_get_devtype(device) : "");
        const bool hasFilesystem = udev_device_get_property_value(device, "ID_FS_TYPE") || QString::fromUtf8(udev_device_get_property_value(device, "ID_FS_USAGE") ? udev_device_get_property_value(device, "ID_FS_USAGE") : "") == QStringLiteral("filesystem");

        if (devtype == QStringLiteral("partition")) {
            partitions.push_back(devnode);
        } else if (devtype == QStringLiteral("disk") && hasFilesystem) {
            filesystemDisks.push_back(devnode);
        } else if (devtype == QStringLiteral("disk")) {
            otherDisks.push_back(devnode);
        }

        udev_device_unref(device);
    }

    udev_enumerate_unref(enumerate);

    std::sort(partitions.begin(), partitions.end());
    std::sort(filesystemDisks.begin(), filesystemDisks.end());
    std::sort(otherDisks.begin(), otherDisks.end());
    partitions.removeDuplicates();
    filesystemDisks.removeDuplicates();
    otherDisks.removeDuplicates();
    partitions.append(filesystemDisks);
    partitions.append(otherDisks);
    partitions.removeDuplicates();
    return partitions;
}

QStringList UpdateController::findUpdateImages() const
{
    QStringList images;

    QDir source(sourcePath());
    if (!source.exists()) {
        return images;
    }

    QDirIterator iterator(
        sourcePath(),
        QStringList{ QStringLiteral("*update.img") },
        QDir::Files,
        QDirIterator::Subdirectories);
    while (iterator.hasNext()) {
        images.push_back(QDir::cleanPath(iterator.next()));
    }

    std::sort(images.begin(), images.end());
    images.removeDuplicates();
    return images;
}

QString UpdateController::selectedImagePath() const
{
    if (m_selectedImage < 0 || m_selectedImage >= m_updateImages.size()) {
        return QString();
    }

    return m_updateImages.at(m_selectedImage);
}

void UpdateController::applyUpdate()
{
    startUpdate(QStringLiteral("apply"));
}

void UpdateController::systemUpdate()
{
    startUpdate(QStringLiteral("boot"));
}

void UpdateController::reboot()
{
    requestPowerAction(QStringLiteral("reboot"), tr("Reboot requested"), tr("Unable to start reboot command"));
}

void UpdateController::shutdown()
{
    requestPowerAction(QStringLiteral("poweroff"), tr("Shutdown requested"), tr("Unable to start shutdown command"));
}

void UpdateController::requestPowerAction(const QString &verb, const QString &requestedStatus, const QString &failedStatus)
{
    if (running()) {
        setStatus(tr("Offline update is still running"));
        return;
    }

    const QString command = systemctlCommand();
    if (command.isEmpty()) {
        setStatus(tr("systemctl command not found"));
        return;
    }

    QStringList arguments;
    arguments << verb;

    appendLog(QStringLiteral("\n[%1] %2 %3\n")
                  .arg(QDateTime::currentDateTime().toString(Qt::ISODate), command, arguments.join(QLatin1Char(' '))));
    if (QProcess::startDetached(command, arguments)) {
        setStatus(requestedStatus);
    } else {
        setStatus(failedStatus);
    }
}

void UpdateController::clearLog()
{
    if (m_log.isEmpty()) {
        return;
    }

    m_log.clear();
    Q_EMIT logChanged();
}

void UpdateController::startUpdate(const QString &mode)
{
    if (running()) {
        setStatus(tr("Offline update is already running"));
        return;
    }

    mountUsbStorage();
    refreshState();
    const QString updateImage = selectedImagePath();
    if (updateImage.isEmpty()) {
        setStatus(tr("No update image selected"));
        return;
    }

    const QString command = updateCommand();
    if (command.isEmpty()) {
        setStatus(tr("offline-update command not found"));
        return;
    }

    QString program = command;
    QStringList arguments;
    arguments << mode;
    arguments << updateImage;

    if (geteuid() != 0) {
        const QString pkexec = pkexecCommand();
        if (pkexec.isEmpty()) {
            setStatus(tr("pkexec is required for system update"));
            return;
        }

        arguments.prepend(command);
        program = pkexec;
    }

    appendLog(QStringLiteral("\n[%1] %2 %3\n")
                  .arg(QDateTime::currentDateTime().toString(Qt::ISODate), program, arguments.join(QLatin1Char(' '))));
    m_process.start(program, arguments);
}

void UpdateController::appendLog(const QString &text)
{
    if (text.isEmpty()) {
        return;
    }

    m_log += text;
    constexpr qsizetype maxLogSize = 32000;
    if (m_log.size() > maxLogSize) {
        m_log = m_log.right(maxLogSize);
    }

    Q_EMIT logChanged();
}

void UpdateController::setStatus(const QString &status)
{
    if (m_status == status) {
        return;
    }

    m_status = status;
    Q_EMIT statusChanged();
}

QString UpdateController::readTrimmed(const QString &path) const
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return QString();
    }

    return QString::fromUtf8(file.readAll()).trimmed();
}

QString UpdateController::systemdMountCommand() const
{
    const QString configured = QString::fromLocal8Bit(qgetenv("CONFIGURATION_SYSTEMD_MOUNT_COMMAND")).trimmed();
    if (!configured.isEmpty()) {
        return configured;
    }

    const QString pathSystemdMount = QStandardPaths::findExecutable(QStringLiteral("systemd-mount"));
    if (!pathSystemdMount.isEmpty()) {
        return pathSystemdMount;
    }

    if (QFile::exists(QStringLiteral("/run/current-system/sw/bin/systemd-mount"))) {
        return QStringLiteral("/run/current-system/sw/bin/systemd-mount");
    }

    return QString();
}

QString UpdateController::updateCommand() const
{
    const QString configured = QString::fromLocal8Bit(qgetenv("CONFIGURATION_OFFLINE_UPDATE_COMMAND")).trimmed();
    if (!configured.isEmpty()) {
        return configured;
    }

    return QStandardPaths::findExecutable(QStringLiteral("offline-update"));
}

QString UpdateController::pkexecCommand() const
{
    const QString pathPkexec = QStandardPaths::findExecutable(QStringLiteral("pkexec"));
    if (!pathPkexec.isEmpty()) {
        return pathPkexec;
    }

    if (QFile::exists(QStringLiteral("/run/wrappers/bin/pkexec"))) {
        return QStringLiteral("/run/wrappers/bin/pkexec");
    }

    return QString();
}

QString UpdateController::systemctlCommand() const
{
    const QString configured = QString::fromLocal8Bit(qgetenv("CONFIGURATION_SYSTEMCTL_COMMAND")).trimmed();
    if (!configured.isEmpty()) {
        return configured;
    }

    const QString pathSystemctl = QStandardPaths::findExecutable(QStringLiteral("systemctl"));
    if (!pathSystemctl.isEmpty()) {
        return pathSystemctl;
    }

    if (QFile::exists(QStringLiteral("/run/current-system/sw/bin/systemctl"))) {
        return QStringLiteral("/run/current-system/sw/bin/systemctl");
    }

    return QString();
}
