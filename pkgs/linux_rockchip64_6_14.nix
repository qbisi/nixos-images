{
  lib,
  buildLinux,
  fetchFromGitHub,
  fetchurl,
  armbianBuild,
  ...
}:
let
  version = "6.14";
  src = fetchurl {
    url = "https://git.kernel.org/torvalds/t/linux-${version}.tar.gz";
    hash = "sha256-fXlg1s4nd0Ppbb2NlPzpPxN5mmm9mj6YQe6//eSr5sI=";
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
