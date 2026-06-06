#include "SoundCheckController.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QTimer>
#include <QUrl>

#include <algorithm>

SoundCheckController::SoundCheckController(QObject *parent)
    : QObject(parent)
{
    QTimer::singleShot(250, this, &SoundCheckController::initializeDevices);
}

QVariantList SoundCheckController::outputDevices() const
{
    QVariantList devices;
    QAudioDevice defaultDevice;
    if (!m_outputs.isEmpty()) {
        defaultDevice = QMediaDevices::defaultAudioOutput();
    }

    for (int i = 0; i < static_cast<int>(m_outputs.size()); ++i) {
        const QAudioDevice &device = m_outputs.at(i);
        QVariantMap item;
        item.insert(QStringLiteral("description"), device.description());
        item.insert(QStringLiteral("isDefault"), device.id() == defaultDevice.id());
        item.insert(QStringLiteral("index"), i);
        devices.push_back(item);
    }

    return devices;
}

int SoundCheckController::selectedDevice() const
{
    return m_selectedDevice;
}

int SoundCheckController::volume() const
{
    return m_volume;
}

bool SoundCheckController::playing() const
{
    return m_player && m_player->playbackState() == QMediaPlayer::PlayingState;
}

QString SoundCheckController::status() const
{
    return m_status;
}

void SoundCheckController::setSelectedDevice(int index)
{
    const int outputCount = static_cast<int>(m_outputs.size());
    const int clamped = std::clamp(index, 0, std::max(0, outputCount - 1));
    if (m_selectedDevice == clamped) {
        return;
    }

    m_selectedDevice = clamped;
    Q_EMIT selectedDeviceChanged();
}

void SoundCheckController::setVolume(int volume)
{
    const int clamped = std::clamp(volume, 0, 100);
    if (m_volume == clamped) {
        return;
    }

    m_volume = clamped;
    if (m_audioOutput) {
        m_audioOutput->setVolume(m_volume / 100.0);
    }
    Q_EMIT volumeChanged();
}

void SoundCheckController::refreshDevices()
{
    if (!m_mediaDevices) {
        initializeDevices();
        return;
    }

    m_outputs = QMediaDevices::audioOutputs();
    if (m_selectedDevice >= static_cast<int>(m_outputs.size())) {
        m_selectedDevice = 0;
        Q_EMIT selectedDeviceChanged();
    }

    Q_EMIT devicesChanged();
    setStatus(m_outputs.isEmpty() ? tr("No audio output devices") : tr("%n audio output(s) ready", nullptr, m_outputs.size()));
}

void SoundCheckController::initializeDevices()
{
    if (m_mediaDevices) {
        return;
    }

    m_mediaDevices = new QMediaDevices(this);
    connect(m_mediaDevices, &QMediaDevices::audioOutputsChanged, this, &SoundCheckController::refreshDevices);
    refreshDevices();
}

void SoundCheckController::playTestSound()
{
    playAlarm();
}

void SoundCheckController::stop()
{
    if (m_player && m_player->playbackState() != QMediaPlayer::StoppedState) {
        m_player->stop();
    }

    Q_EMIT playingChanged();
    if (!m_outputs.isEmpty()) {
        setStatus(tr("Sound check stopped"));
    }
}

void SoundCheckController::playAlarm()
{
    if (m_outputs.isEmpty()) {
        setStatus(tr("No audio output devices"));
        return;
    }

    const QString file = soundFile();
    if (!QFile::exists(file)) {
        setStatus(tr("Missing test sound: %1").arg(file));
        return;
    }

    ensurePlayer();
    m_audioOutput->setDevice(currentDevice());
    m_audioOutput->setVolume(m_volume / 100.0);
    m_player->setSource(QUrl::fromLocalFile(file));
    m_player->play();
    setStatus(tr("Playing alarm test sound"));
}

void SoundCheckController::ensurePlayer()
{
    if (m_player) {
        return;
    }

    m_audioOutput = new QAudioOutput(this);
    m_player = new QMediaPlayer(this);
    m_player->setAudioOutput(m_audioOutput);

    connect(m_player, &QMediaPlayer::playbackStateChanged, this, [this] {
        Q_EMIT playingChanged();
    });
    connect(m_player, &QMediaPlayer::mediaStatusChanged, this, [this](QMediaPlayer::MediaStatus status) {
        if (status == QMediaPlayer::EndOfMedia) {
            stop();
        }
    });
    connect(m_player, &QMediaPlayer::errorOccurred, this, [this](QMediaPlayer::Error error, const QString &errorString) {
        Q_UNUSED(error)
        setStatus(tr("Sound check failed: %1").arg(errorString));
    });
}

void SoundCheckController::setStatus(const QString &status)
{
    if (m_status == status) {
        return;
    }

    m_status = status;
    Q_EMIT statusChanged();
}

QAudioDevice SoundCheckController::currentDevice() const
{
    if (m_outputs.isEmpty()) {
        return QAudioDevice();
    }

    const int outputCount = static_cast<int>(m_outputs.size());
    const int index = std::clamp(m_selectedDevice, 0, outputCount - 1);
    return m_outputs.at(index);
}

QString SoundCheckController::soundFile() const
{
    const QString configured = QString::fromLocal8Bit(qgetenv("CONFIGURATION_SOUND_CHECK_FILE")).trimmed();
    if (!configured.isEmpty()) {
        return configured;
    }

    return QDir(QCoreApplication::applicationDirPath()).filePath(QStringLiteral("../share/configuration/alarm.mp3"));
}
