#pragma once

#include <QAbstractListModel>
#include <QSocketNotifier>
#include <QString>
#include <QVector>

struct udev;
struct udev_monitor;

class UsbDeviceModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)

public:
    enum Roles {
        NameRole = Qt::UserRole + 1,
        VendorIdRole,
        ProductIdRole,
        ManufacturerRole,
        ProductRole,
        SerialRole,
        SpeedRole,
        BusRole,
        DeviceRole,
        PathRole,
    };

    explicit UsbDeviceModel(QObject *parent = nullptr);
    ~UsbDeviceModel() override;

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    int count() const;
    QString status() const;

    Q_INVOKABLE void refresh();

Q_SIGNALS:
    void countChanged();
    void statusChanged();

private:
    struct UsbDevice {
        QString name;
        QString vendorId;
        QString productId;
        QString manufacturer;
        QString product;
        QString serial;
        QString speed;
        QString bus;
        QString device;
        QString path;
    };

    QString sysattr(struct udev_device *device, const char *name) const;
    void setupMonitor();
    void setStatus(const QString &status);

    QVector<UsbDevice> m_devices;
    udev *m_udev = nullptr;
    udev_monitor *m_monitor = nullptr;
    QSocketNotifier *m_notifier = nullptr;
    QString m_status;
};
