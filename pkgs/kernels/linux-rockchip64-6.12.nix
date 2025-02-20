{
  lib,
  buildLinux,
  fetchFromGitHub,
  fetchurl,
  stdenv,
  ...
}:
let
  version = "6.12.15";
  src = fetchurl {
    url = "mirror://kernel/linux/kernel/v${lib.versions.major version}.x/linux-${version}.tar.xz";
    hash = "sha256-X/W9hOoOIsU0NzAttdOU0Kkti4saiM4g0QmCmOn3Ywo=";
  };
  armbianBuild = fetchFromGitHub {
    owner = "qbisi";
    repo = "build";
    rev = "fe748696ea14a7f317fd2d049de431bfbc44dfc3";
    nonConeMode = true;
    sparseCheckout = [
      "config/kernel/*.config"
      "patch/kernel/**/*.patch"
    ];
    hash = "sha256-BYrRIdCKfWPitlGkT63KVn6aVK2CKJxCEBnc3InV918=";
  };
  defconfigFile = "${armbianBuild}/config/kernel/linux-rockchip64-edge.config";
  patchDir = "${armbianBuild}/patch/kernel/archive/rockchip64-6.12";
  kernelPatches = (
    map (p: {
      name = baseNameOf p;
      patch = p;
    }) (lib.filesystem.listFilesRecursive patchDir)
  );
  structuredExtraConfig = with lib.kernel; {
    # FW_LOADER
    FW_LOADER_COMPRESS = yes;
    FW_LOADER_COMPRESS_ZSTD = yes;
    # LED_TRIGGER
    LEDS_TRIGGER_NETDEV = yes;
    # HDMI
    PHY_ROCKCHIP_SAMSUNG_HDPTX = yes;
    # NVME
    PHY_ROCKCHIP_SNPS_PCIE3 = yes;
    # MMC
    MMC_BLOCK = yes;
    # USB
    TYPEC = yes;
    PHY_ROCKCHIP_USBDP = yes;
  };
in
buildLinux {
  inherit
    version
    src
    defconfigFile
    kernelPatches
    structuredExtraConfig
    ;
  enableCommonConfig = false;
  extraConfig = "";
  ignoreConfigErrors = true;
  autoModules = false;
  extraMakeFlags = [ "KCFLAGS=-march=armv8-a+crypto" ];
}
