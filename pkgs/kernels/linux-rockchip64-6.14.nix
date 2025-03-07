{
  lib,
  buildLinux,
  fetchFromGitHub,
  fetchurl,
  stdenv,
  ...
}:
let
  version = "6.14-rc5";
  src = fetchurl {
    url = "https://git.kernel.org/torvalds/t/linux-${version}.tar.gz";
    hash = "sha256-KjLn0ghiOtQm3izH/L+27htXBcl8ledOh1/6Kopw0s0=";
  };
  armbianBuild = fetchFromGitHub {
    owner = "armbian";
    repo = "build";
    rev = "db3615f7b0d784728f87e6a95c57607001790690";
    nonConeMode = true;
    sparseCheckout = [
      "config/kernel/*.config"
      "patch/kernel/**/*.patch"
    ];
    hash = "sha256-lWcag42GZhaWW4zZKeiWQO5Vh57QB/K6gCmdAZ1BIR0=";
  };
  defconfigFile = "${armbianBuild}/config/kernel/linux-rockchip64-edge.config";
  patchDir = "${armbianBuild}/patch/kernel/archive/rockchip64-6.14";
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
