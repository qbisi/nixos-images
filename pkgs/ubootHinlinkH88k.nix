{
  buildUBoot,
  fetchFromGitHub,
  gcc12Stdenv,
  armTrustedFirmwareRK3588,
  rkbin,
}:
buildUBoot {
  src = fetchFromGitHub {
    owner = "qbisi";
    repo = "u-boot";
    rev = "drm-dirty";
    sha256 = "sha256-c9Pq9gWGNQWibaDqXTFenD8Q3/G0DnYnUCvyNZNyKmw=";
  };
  version = "2024.07";
  defconfig = "hinlink-h88k-rk3588_defconfig";
  stdenv = gcc12Stdenv;
  extraMeta.platforms = [ "aarch64-linux" ];
  BL31 = "${armTrustedFirmwareRK3588}/bl31.elf";
  ROCKCHIP_TPL = rkbin.TPL_RK3588;
  filesToInstall = [
    "u-boot.itb"
    "idbloader.img"
    "u-boot-rockchip.bin"
  ];
}
