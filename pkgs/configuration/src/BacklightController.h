#pragma once

#include <QObject>
#include <QString>
#include <QTimer>

class BacklightController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool available READ available NOTIFY deviceChanged)
    Q_PROPERTY(QString deviceName READ deviceName NOTIFY deviceChanged)
    Q_PROPERTY(int brightness READ brightness WRITE setBrightness NOTIFY brightnessChanged)
    Q_PROPERTY(int maxBrightness READ maxBrightness NOTIFY deviceChanged)
    Q_PROPERTY(int percent READ percent WRITE setPercent NOTIFY brightnessChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)

public:
    explicit BacklightController(QObject *parent = nullptr);

    bool available() const;
    QString deviceName() const;
    int brightness() const;
    int maxBrightness() const;
    int percent() const;
    QString status() const;

    void setBrightness(int value);
    void setPercent(int value);

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void stepDown();
    Q_INVOKABLE void stepUp();

Q_SIGNALS:
    void brightnessChanged();
    void deviceChanged();
    void statusChanged();

private:
    void setStatus(const QString &status);
    bool readIntFile(const QString &path, int *value) const;
    bool writeIntFile(const QString &path, int value, QString *error);
    void selectDevice();
    void readBrightness();

    QString m_devicePath;
    QString m_deviceName;
    int m_brightness = 0;
    int m_maxBrightness = 0;
    QString m_status;
    QTimer m_refreshTimer;
};
