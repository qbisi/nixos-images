{
  buildUBoot,
  emptyDirectory,
  armTrustedFirmwareRK3399,
  rkbin,
}:
buildUBoot {
  defconfig = "generic-rk3399_defconfig";
  BL31 = "${armTrustedFirmwareRK3399}/bl31.elf";
  ROCKCHIP_TPL = "${rkbin}/bin/rk33/rk3399_ddr_800MHz_v1.30.bin";
  filesToInstall = [
    "u-boot.itb"
    "idbloader.img"
    "u-boot-rockchip.bin"
  ];
  prePatch = ''
    cp ${../.}/dts/mainline/rk3399-firefly-core-3399-jd4.dts arch/arm/dts
  '';
  extraConfig = ''
    CONFIG_DEFAULT_DEVICE_TREE="rk3399-firefly-core-3399-jd4"
    CONFIG_DEFAULT_FDT_FILE="rockchip/rk3399-firefly-core-3399-jd4.dtb"
    CONFIG_ROCKCHIP_EXTERNAL_TPL=y
    CONFIG_VIDEO=y
    CONFIG_DISPLAY=y
    CONFIG_VIDEO_ROCKCHIP=y
    CONFIG_DISPLAY_ROCKCHIP_HDMI=y
    CONFIG_BOOTSTD_FULL=y
    CONFIG_BOOTCOMMAND="bootmenu"
    CONFIG_BOOTMENU_DISABLE_UBOOT_CONSOLE=y
    CONFIG_CMD_BOOTMENU=y
    CONFIG_CMD_EFICONFIG=y
    CONFIG_USE_PREBOOT=y
    CONFIG_PREBOOT="usb start;"
    CONFIG_PHY_ROCKCHIP_INNO_USB2=y
    CONFIG_PHY_ROCKCHIP_TYPEC=y
    CONFIG_PHY_ROCKCHIP_USBDP=y
    CONFIG_USB=y
    CONFIG_USB_XHCI_HCD=y
    CONFIG_USB_XHCI_DWC3=y
    CONFIG_USB_EHCI_HCD=y
    CONFIG_USB_EHCI_GENERIC=y
    CONFIG_USB_OHCI_HCD=y
    CONFIG_USB_OHCI_GENERIC=y
    CONFIG_USB_KEYBOARD=y
    CONFIG_SYS_USB_EVENT_POLL_VIA_CONTROL_EP=y
  '';
}
