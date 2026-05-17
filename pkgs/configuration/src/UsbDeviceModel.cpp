#include "UsbDeviceModel.h"

#include <libudev.h>

#include <QTimer>

#include <algorithm>

UsbDeviceModel::UsbDeviceModel(QObject *parent)
    : QAbstractListModel(parent)
    , m_udev(udev_new())
{
    setupMonitor();
    QTimer::singleShot(150, this, &UsbDeviceModel::refresh);
}

UsbDeviceModel::~UsbDeviceModel()
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

int UsbDeviceModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid()) {
        return 0;
    }

    return m_devices.size();
}

QVariant UsbDeviceModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_devices.size()) {
        return {};
    }

    const UsbDevice &device = m_devices.at(index.row());
    switch (role) {
    case NameRole:
        return device.name;
    case VendorIdRole:
        return device.vendorId;
    case ProductIdRole:
        return device.productId;
    case ManufacturerRole:
        return device.manufacturer;
    case ProductRole:
        return device.product;
    case SerialRole:
        return device.serial;
    case SpeedRole:
        return device.speed;
    case BusRole:
        return device.bus;
    case DeviceRole:
        return device.device;
    case PathRole:
        return device.path;
    default:
        return {};
    }
}

QHash<int, QByteArray> UsbDeviceModel::roleNames() const
{
    return {
        {NameRole, "name"},
        {VendorIdRole, "vendorId"},
        {ProductIdRole, "productId"},
        {ManufacturerRole, "manufacturer"},
        {ProductRole, "product"},
        {SerialRole, "serial"},
        {SpeedRole, "speed"},
        {BusRole, "bus"},
        {DeviceRole, "device"},
        {PathRole, "path"},
    };
}

int UsbDeviceModel::count() const
{
    return m_devices.size();
}

QString UsbDeviceModel::status() const
{
    return m_status;
}

void UsbDeviceModel::refresh()
{
    QVector<UsbDevice> devices;

    if (!m_udev) {
        setStatus(tr("USB monitor unavailable"));
        return;
    }

    udev_enumerate *enumerate = udev_enumerate_new(m_udev);
    if (!enumerate) {
        setStatus(tr("Unable to enumerate USB devices"));
        return;
    }

    udev_enumerate_add_match_subsystem(enumerate, "usb");
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

        const char *devtype = udev_device_get_devtype(device);
        if (devtype && qstrcmp(devtype, "usb_device") == 0) {
            UsbDevice item;
            item.vendorId = sysattr(device, "idVendor");
            item.productId = sysattr(device, "idProduct");
            item.manufacturer = sysattr(device, "manufacturer");
            item.product = sysattr(device, "product");
            item.serial = sysattr(device, "serial");
            item.speed = sysattr(device, "speed");
            item.bus = sysattr(device, "busnum");
            item.device = sysattr(device, "devnum");
            item.path = QString::fromUtf8(path);

            const QString deviceClass = sysattr(device, "bDeviceClass");
            if (!item.vendorId.isEmpty() && !item.productId.isEmpty() && deviceClass != QStringLiteral("09")) {
                item.name = item.product;
                if (item.name.isEmpty()) {
                    item.name = tr("USB Device %1:%2").arg(item.vendorId, item.productId);
                }
                devices.push_back(item);
            }
        }

        udev_device_unref(device);
    }

    udev_enumerate_unref(enumerate);

    std::sort(devices.begin(), devices.end(), [](const UsbDevice &left, const UsbDevice &right) {
        if (left.bus == right.bus) {
            return left.device < right.device;
        }
        return left.bus < right.bus;
    });

    const int oldCount = m_devices.size();
    beginResetModel();
    m_devices = devices;
    endResetModel();

    if (oldCount != m_devices.size()) {
        Q_EMIT countChanged();
    }

    setStatus(m_devices.isEmpty() ? tr("No plugged USB devices") : tr("%n USB device(s) plugged", nullptr, m_devices.size()));
}

QString UsbDeviceModel::sysattr(udev_device *device, const char *name) const
{
    const char *value = udev_device_get_sysattr_value(device, name);
    return value ? QString::fromUtf8(value).trimmed() : QString();
}

void UsbDeviceModel::setupMonitor()
{
    if (!m_udev) {
        return;
    }

    m_monitor = udev_monitor_new_from_netlink(m_udev, "udev");
    if (!m_monitor) {
        return;
    }

    udev_monitor_filter_add_match_subsystem_devtype(m_monitor, "usb", "usb_device");
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
        while (udev_device *event = udev_monitor_receive_device(m_monitor)) {
            udev_device_unref(event);
        }
        QTimer::singleShot(150, this, &UsbDeviceModel::refresh);
    });
}

void UsbDeviceModel::setStatus(const QString &status)
{
    if (m_status == status) {
        return;
    }

    m_status = status;
    Q_EMIT statusChanged();
}
