#pragma once

#include <QAudioDevice>
#include <QAudioOutput>
#include <QMediaDevices>
#include <QMediaPlayer>
#include <QObject>
#include <QVariantList>

class SoundCheckController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList outputDevices READ outputDevices NOTIFY devicesChanged)
    Q_PROPERTY(int selectedDevice READ selectedDevice WRITE setSelectedDevice NOTIFY selectedDeviceChanged)
    Q_PROPERTY(int volume READ volume WRITE setVolume NOTIFY volumeChanged)
    Q_PROPERTY(bool playing READ playing NOTIFY playingChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)

public:
    explicit SoundCheckController(QObject *parent = nullptr);

    QVariantList outputDevices() const;
    int selectedDevice() const;
    int volume() const;
    bool playing() const;
    QString status() const;

    void setSelectedDevice(int index);
    void setVolume(int volume);

    Q_INVOKABLE void refreshDevices();
    Q_INVOKABLE void playTestSound();
    Q_INVOKABLE void stop();

Q_SIGNALS:
    void devicesChanged();
    void selectedDeviceChanged();
    void volumeChanged();
    void playingChanged();
    void statusChanged();

private:
    void initializeDevices();
    void ensurePlayer();
    void playAlarm();
    void setStatus(const QString &status);
    QAudioDevice currentDevice() const;
    QString soundFile() const;

    QMediaDevices *m_mediaDevices = nullptr;
    QAudioOutput *m_audioOutput = nullptr;
    QMediaPlayer *m_player = nullptr;
    QList<QAudioDevice> m_outputs;
    int m_selectedDevice = 0;
    int m_volume = 85;
    QString m_status;
};
