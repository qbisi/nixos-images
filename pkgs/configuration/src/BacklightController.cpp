#include "BacklightController.h"

#include <QDir>
#include <QFile>
#include <QTextStream>

#include <algorithm>

BacklightController::BacklightController(QObject *parent)
    : QObject(parent)
{
    connect(&m_refreshTimer, &QTimer::timeout, this, &BacklightController::refresh);
    m_refreshTimer.setInterval(2000);
    m_refreshTimer.start();
    QTimer::singleShot(50, this, &BacklightController::refresh);
}

bool BacklightController::available() const
{
    return !m_devicePath.isEmpty() && m_maxBrightness > 0;
}

QString BacklightController::deviceName() const
{
    return m_deviceName;
}

int BacklightController::brightness() const
{
    return m_brightness;
}

int BacklightController::maxBrightness() const
{
    return m_maxBrightness;
}

int BacklightController::percent() const
{
    if (m_maxBrightness <= 0) {
        return 0;
    }

    return std::clamp(qRound((m_brightness * 100.0) / m_maxBrightness), 0, 100);
}

QString BacklightController::status() const
{
    return m_status;
}

void BacklightController::setBrightness(int value)
{
    if (!available()) {
        setStatus(tr("No backlight device found"));
        return;
    }

    const int clamped = std::clamp(value, 0, m_maxBrightness);
    QString error;
    if (!writeIntFile(m_devicePath + QStringLiteral("/brightness"), clamped, &error)) {
        setStatus(tr("Brightness write failed: %1").arg(error));
        return;
    }

    readBrightness();
    setStatus(tr("Brightness set to %1%").arg(percent()));
}

void BacklightController::setPercent(int value)
{
    if (!available()) {
        setStatus(tr("No backlight device found"));
        return;
    }

    const int clampedPercent = std::clamp(value, 0, 100);
    int target = qRound((m_maxBrightness * clampedPercent) / 100.0);
    if (clampedPercent > 0) {
        target = std::max(1, target);
    }
    setBrightness(target);
}

void BacklightController::refresh()
{
    const QString previousPath = m_devicePath;
    selectDevice();
    readBrightness();

    if (previousPath != m_devicePath) {
        Q_EMIT deviceChanged();
    }
}

void BacklightController::stepDown()
{
    setPercent(percent() - 5);
}

void BacklightController::stepUp()
{
    setPercent(percent() + 5);
}

void BacklightController::setStatus(const QString &status)
{
    if (m_status == status) {
        return;
    }

    m_status = status;
    Q_EMIT statusChanged();
}

bool BacklightController::readIntFile(const QString &path, int *value) const
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return false;
    }

    bool ok = false;
    const int parsed = QString::fromUtf8(file.readAll()).trimmed().toInt(&ok);
    if (!ok) {
        return false;
    }

    *value = parsed;
    return true;
}

bool BacklightController::writeIntFile(const QString &path, int value, QString *error)
{
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        if (error) {
            *error = file.errorString();
        }
        return false;
    }

    QTextStream stream(&file);
    stream << value << Qt::endl;
    if (stream.status() != QTextStream::Ok) {
        if (error) {
            *error = tr("device rejected the value");
        }
        return false;
    }

    return true;
}

void BacklightController::selectDevice()
{
    QDir backlightDir(QStringLiteral("/sys/class/backlight"));
    const QStringList entries = backlightDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name);

    QString bestPath;
    QString bestName;
    int bestMax = 0;

    for (const QString &entry : entries) {
        const QString path = backlightDir.absoluteFilePath(entry);
        int maxBrightness = 0;
        if (!readIntFile(path + QStringLiteral("/max_brightness"), &maxBrightness) || maxBrightness <= 0) {
            continue;
        }

        if (maxBrightness > bestMax) {
            bestPath = path;
            bestName = entry;
            bestMax = maxBrightness;
        }
    }

    const bool changed = bestPath != m_devicePath || bestName != m_deviceName || bestMax != m_maxBrightness;
    m_devicePath = bestPath;
    m_deviceName = bestName;
    m_maxBrightness = bestMax;

    if (!available()) {
        m_brightness = 0;
        setStatus(tr("No backlight device found"));
    }

    if (changed) {
        Q_EMIT deviceChanged();
    }
}

void BacklightController::readBrightness()
{
    if (!available()) {
        return;
    }

    int value = 0;
    if (!readIntFile(m_devicePath + QStringLiteral("/brightness"), &value)) {
        setStatus(tr("Unable to read brightness"));
        return;
    }

    value = std::clamp(value, 0, m_maxBrightness);
    if (value != m_brightness) {
        m_brightness = value;
        Q_EMIT brightnessChanged();
    }

    if (m_status.isEmpty() || m_status.startsWith(tr("No backlight")) || m_status.startsWith(tr("Unable"))) {
        setStatus(tr("Backlight ready"));
    }
}
