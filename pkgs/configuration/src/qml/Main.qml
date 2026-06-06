import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: root

    width: 720
    height: 720
    minimumWidth: 560
    minimumHeight: 560
    visible: false
    flags: Qt.FramelessWindowHint
    title: qsTr("Configuration")
    color: "#f5f0e8"

    readonly property bool twoColumn: width >= 680
    readonly property color ink: "#202528"
    readonly property color muted: "#5c6568"
    readonly property color panel: "#fffaf1"
    readonly property color surface: "#ffffff"
    readonly property color border: "#d8d0c3"
    readonly property color accent: "#1f6f78"
    readonly property color warm: "#d95f4b"
    readonly property color green: "#477c55"
    readonly property color gold: "#f2b84b"
    readonly property int touch: 52
    readonly property int pageMargin: twoColumn ? 16 : 12

    component SectionBox: Rectangle {
        id: section

        property string title: ""
        property string statusText: ""
        property string iconName: ""
        property color statusColor: root.accent
        property int panelHeight: 0
        default property alias content: body.data

        Layout.fillWidth: true
        Layout.minimumHeight: Math.max(panelHeight, implicitHeight)
        implicitHeight: contentLayout.implicitHeight + 28
        color: root.panel
        border.color: root.border
        radius: 8

        ColumnLayout {
            id: contentLayout

            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                ToolButton {
                    Layout.preferredWidth: 44
                    Layout.preferredHeight: 44
                    icon.name: section.iconName
                    icon.width: 24
                    icon.height: 24
                    focusPolicy: Qt.NoFocus

                    background: Rectangle {
                        radius: 8
                        color: Qt.rgba(section.statusColor.r, section.statusColor.g, section.statusColor.b, 0.18)
                        border.color: Qt.rgba(section.statusColor.r, section.statusColor.g, section.statusColor.b, 0.5)
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Label {
                        Layout.fillWidth: true
                        text: section.title
                        color: root.ink
                        font.pixelSize: 19
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Label {
                        Layout.fillWidth: true
                        text: section.statusText
                        color: root.muted
                        font.pixelSize: 13
                        elide: Text.ElideRight
                    }
                }
            }

            ColumnLayout {
                id: body

                Layout.fillWidth: true
                spacing: 10
            }
        }
    }

    component PrimaryButton: Button {
        property string iconName: ""
        property color buttonColor: root.accent

        Layout.fillWidth: true
        Layout.minimumHeight: root.touch
        icon.name: iconName
        icon.width: 22
        icon.height: 22
        font.pixelSize: 15
        leftPadding: 14
        rightPadding: 14
        spacing: 8
        palette.buttonText: "white"

        background: Rectangle {
            radius: 8
            color: parent.enabled ? (parent.down ? Qt.darker(parent.buttonColor, 1.18) : parent.hovered ? Qt.lighter(parent.buttonColor, 1.08) : parent.buttonColor) : "#a7acae"
        }
    }

    component IconButton: Button {
        property string iconName: ""

        Layout.preferredWidth: root.touch
        Layout.preferredHeight: root.touch
        icon.name: iconName
        icon.width: 23
        icon.height: 23
        palette.buttonText: root.ink

        background: Rectangle {
            radius: 8
            color: parent.down ? "#e3dccf" : parent.hovered ? "#eee7db" : root.surface
            border.color: root.border
        }
    }

    Item {
        id: header

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: root.pageMargin
        height: root.touch

        Button {
            width: root.touch
            height: root.touch
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            icon.name: "go-previous"
            icon.width: 23
            icon.height: 23
            onClicked: {
                root.visible = false
            }

            background: Rectangle {
                radius: 8
                color: parent.down ? "#e3dccf" : parent.hovered ? "#eee7db" : root.surface
                border.color: root.border
            }
        }

        Label {
            width: Math.max(0, parent.width - (root.touch + 12) * 2)
            anchors.centerIn: parent
            text: qsTr("Configuration")
            color: root.ink
            font.pixelSize: 28
            font.weight: Font.Bold
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
    }

    ScrollView {
        id: scroller

        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: root.pageMargin
        anchors.rightMargin: root.pageMargin
        anchors.bottomMargin: root.pageMargin
        anchors.topMargin: root.pageMargin
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        ColumnLayout {
            width: scroller.availableWidth
            spacing: 14

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 14

                SectionBox {
                    title: qsTr("Backlight")
                    statusText: backlight.available ? qsTr("%1 ready").arg(backlight.deviceName) : backlight.status
                    iconName: "weather-clear"
                    statusColor: backlight.available ? root.accent : root.warm
                    panelHeight: root.twoColumn ? 196 : 0

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Label {
                            text: qsTr("%1%").arg(backlight.percent)
                            color: root.ink
                            font.pixelSize: 42
                            font.weight: Font.Bold
                        }

                        Label {
                            Layout.fillWidth: true
                            text: backlight.available ? qsTr("%1 / %2").arg(backlight.brightness).arg(backlight.maxBrightness) : qsTr("No device")
                            color: root.muted
                            font.pixelSize: 14
                            horizontalAlignment: Text.AlignRight
                            elide: Text.ElideRight
                        }
                    }

                    Slider {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        from: 0
                        to: 100
                        stepSize: 0
                        live: true
                        snapMode: Slider.NoSnap
                        enabled: backlight.available
                        value: backlight.percent
                        onMoved: backlight.percent = Math.round(value)
                    }

                }

                SectionBox {
                    title: qsTr("USB Devices")
                    statusText: usbDevices.status
                    iconName: "drive-removable-media-usb"
                    statusColor: usbDevices.count > 0 ? root.green : root.warm
                    panelHeight: root.twoColumn ? 238 : 0

                    Label {
                        Layout.fillWidth: true
                        text: usbDevices.count === 1 ? qsTr("1 plugged device") : qsTr("%1 plugged devices").arg(usbDevices.count)
                        color: root.ink
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Repeater {
                            model: usbDevices

                            delegate: Rectangle {
                                required property string name
                                required property string manufacturer
                                required property string vendorId
                                required property string productId
                                required property string serial
                                required property string speed
                                required property string bus
                                required property string device

                                Layout.fillWidth: true
                                Layout.preferredHeight: 58
                                radius: 8
                                color: root.surface
                                border.color: root.border

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 1

                                    RowLayout {
                                        Layout.fillWidth: true

                                        Label {
                                            Layout.fillWidth: true
                                            text: name
                                            color: root.ink
                                            font.pixelSize: 15
                                            font.weight: Font.DemiBold
                                            elide: Text.ElideRight
                                        }

                                        Label {
                                            text: speed.length > 0 ? speed + "M" : ""
                                            color: root.accent
                                            font.pixelSize: 12
                                        }
                                    }

                                    Label {
                                        Layout.fillWidth: true
                                        text: qsTr("%1  %2:%3").arg(manufacturer.length > 0 ? manufacturer : qsTr("Unknown")).arg(vendorId).arg(productId)
                                        color: root.muted
                                        font.pixelSize: 12
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }

                        Label {
                            Layout.fillWidth: true
                            Layout.minimumHeight: 58
                            visible: usbDevices.count === 0
                            text: qsTr("No plugged USB devices")
                            color: root.muted
                            font.pixelSize: 15
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }

                SectionBox {
                    title: qsTr("Sound Check")
                    statusText: sound.status
                    iconName: "audio-volume-high"
                    statusColor: sound.outputDevices.length > 0 ? root.accent : root.warm
                    panelHeight: root.twoColumn ? 258 : 0

                    ComboBox {
                        Layout.fillWidth: true
                        Layout.minimumHeight: root.touch
                        model: sound.outputDevices
                        textRole: "description"
                        enabled: sound.outputDevices.length > 0
                        currentIndex: sound.selectedDevice
                        onActivated: sound.selectedDevice = currentIndex
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Label {
                            Layout.fillWidth: true
                            text: qsTr("Volume")
                            color: root.muted
                            font.pixelSize: 14
                            elide: Text.ElideRight
                        }

                        Label {
                            text: qsTr("%1%").arg(sound.volume)
                            color: root.ink
                            font.pixelSize: 18
                            font.weight: Font.DemiBold
                        }
                    }

                    Slider {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        from: 0
                        to: 100
                        stepSize: 0
                        live: true
                        snapMode: Slider.NoSnap
                        value: sound.volume
                        onMoved: sound.volume = Math.round(value)
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        rowSpacing: 10
                        columnSpacing: 10

                        PrimaryButton {
                            text: qsTr("Play")
                            iconName: "media-playback-start"
                            enabled: sound.outputDevices.length > 0
                            onClicked: sound.playTestSound()
                        }

                        Button {
                            Layout.fillWidth: true
                            Layout.minimumHeight: root.touch
                            text: qsTr("Stop")
                            icon.name: "media-playback-stop"
                            icon.width: 22
                            icon.height: 22
                            enabled: sound.playing
                            onClicked: sound.stop()
                        }
                    }
                }

                SectionBox {
                    title: qsTr("Offline Update")
                    statusText: updates.status
                    iconName: "system-software-update"
                    statusColor: updates.imageDetected ? root.green : root.warm
                    panelHeight: root.twoColumn ? 360 : 0

                    ComboBox {
                        Layout.fillWidth: true
                        Layout.minimumHeight: root.touch
                        model: updates.updateImageNames
                        enabled: updates.updateImages.length > 0 && !updates.running
                        currentIndex: updates.selectedImage
                        displayText: updates.updateImages.length > 0 ? currentText : qsTr("No update image found")
                        onActivated: updates.selectedImage = currentIndex
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: root.twoColumn ? 3 : 1
                        rowSpacing: 10
                        columnSpacing: 10

                        PrimaryButton {
                            text: qsTr("Update")
                            iconName: "system-software-update"
                            enabled: updates.imageDetected && !updates.running
                            onClicked: updates.systemUpdate()
                        }

                        PrimaryButton {
                            text: qsTr("Reboot")
                            iconName: "system-reboot"
                            buttonColor: root.warm
                            enabled: !updates.running
                            onClicked: updates.reboot()
                        }

                        PrimaryButton {
                            text: qsTr("Shutdown")
                            iconName: "system-shutdown"
                            buttonColor: root.warm
                            enabled: !updates.running
                            onClicked: updates.shutdown()
                        }
                    }

                    ProgressBar {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 6
                        indeterminate: updates.running
                        visible: updates.running
                    }

                    Label {
                        Layout.fillWidth: true
                        text: updates.lastBoot.length > 0 ? qsTr("Updated %1").arg(updates.lastBoot) : qsTr("No update yet")
                        color: root.muted
                        font.pixelSize: 13
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 70
                        radius: 8
                        color: root.ink

                        ScrollView {
                            anchors.fill: parent
                            anchors.margins: 8
                            clip: true

                            TextArea {
                                text: updates.log.length > 0 ? updates.log : qsTr("offline-update output")
                                readOnly: true
                                wrapMode: TextEdit.Wrap
                                color: root.panel
                                selectedTextColor: root.ink
                                selectionColor: root.gold
                                font.family: "monospace"
                                font.pixelSize: 12
                                background: null
                            }
                        }
                    }
                }
            }
        }
    }
}
