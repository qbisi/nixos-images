{
  lib,
  buildLinux,
  fetchFromGitHub,
  fetchurl,
  armbianBuild,
  linux_6_15,
  ...
}:
let
  defconfigFile = "${armbianBuild}/config/kernel/linux-rockchip64-edge.config";
  patchDir = "${armbianBuild}/patch/kernel/archive/rockchip64-6.15";
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
    # MPTCP
    MPTCP = yes;
    INET_MPTCP_DIAG = module;
  };
in
buildLinux {
  inherit (linux_6_15)
    version
    src
    ;
  inherit
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
