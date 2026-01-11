{
  buildUBoot,
  fetchFromGitHub,
  armTrustedFirmwareRK3588,
  rkbin,
}:
buildUBoot {
  defconfig = "cm3588-nas-rk3588_defconfig";
  extraMeta.platforms = [ "aarch64-linux" ];
  BL31 = "${armTrustedFirmwareRK3588}/bl31.elf";
  ROCKCHIP_TPL = rkbin.TPL_RK3588;
  filesToInstall = [
    "u-boot.itb"
    "idbloader.img"
    "u-boot-rockchip.bin"
  ];
  extraConfig = ''
    CONFIG_BOOTSTD_FULL=y
  '';
}
