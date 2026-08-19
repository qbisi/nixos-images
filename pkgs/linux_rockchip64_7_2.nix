{
  lib,
  fetchurl,
  buildLinux,
  linux_7_2,
  ...
}:
buildLinux {
  inherit (linux_7_2) version src;

  defconfigFile = fetchurl {
    url = "https://raw.githubusercontent.com/armbian/build/bb3eb9b7d99855fc80f9afa8b0997b47a5a25f47/config/kernel/linux-rockchip64-edge.config";
    hash = "sha256-+pZWmADJL88RVn/YSf5v8hl8xkP8ixninylPmfT1ZsI=";
  };

  kernelPatches = lib.concatMap lib.patchesIn [
    ../patches/kernel/7.2
    ../patches/kernel
  ];

  structuredExtraConfig = with lib.kernel; {
    # FW_LOADER
    FW_LOADER_COMPRESS = yes;
    FW_LOADER_COMPRESS_ZSTD = yes;
    # PCIE PHY
    PHY_ROCKCHIP_SNPS_PCIE3 = yes;
    # MPTCP
    MPTCP = yes;
    INET_MPTCP_DIAG = module;
  };

  enableCommonConfig = false;
  extraConfig = "";
  ignoreConfigErrors = true;
  autoModules = false;
  extraMeta.platforms = [ "aarch64-linux" ];
}
