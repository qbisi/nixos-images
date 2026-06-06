{
  armbian-firmware,
}:
armbian-firmware.override {
  filters = [
    "arm/mali/*"
    "rtl_nic/*"
    "mediatek/*"
    "brcm/*"
  ];
}
