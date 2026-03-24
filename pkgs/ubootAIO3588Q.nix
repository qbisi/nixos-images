{
  buildUBoot,
  fetchFromGitHub,
  armTrustedFirmwareRK3588,
  rkbin,
}:
buildUBoot {
  src = fetchFromGitHub {
    owner = "qbisi";
    repo = "u-boot";
    tag = "v2024.07";
    hash = "sha256-mJ2TBy0Y5ZtcGFgtU5RKr0UDUp5FWzojbFb+o/ebRJU=";
  };
  version = "2024.07";
  defconfig = "rock5b-rk3588_defconfig";
  extraMeta.platforms = [ "aarch64-linux" ];
  BL31 = "${armTrustedFirmwareRK3588}/bl31.elf";
  ROCKCHIP_TPL = rkbin.TPL_RK3588;
  filesToInstall = [
    "u-boot.itb"
    "idbloader.img"
    "u-boot-rockchip.bin"
    "u-boot-rockchip-spi.bin"
  ];
  # disable smbios such that sound card can find profile in alsa-ucm-conf
  # see https://github.com/alsa-project/alsa-ucm-conf/pull/374
  extraConfig = ''
    CONFIG_SMBIOS=n
  '';
}
