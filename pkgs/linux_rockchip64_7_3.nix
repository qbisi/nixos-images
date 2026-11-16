{
  lib,
  fetchurl,
  buildLinux,
  linux_7_3,
  ...
}:
buildLinux {
  inherit (linux_7_3) version src;

  defconfigFile = fetchurl {
    url = "https://raw.githubusercontent.com/armbian/build/18e87d5385f9191419e6afa646080b68fbe7a1d5/config/kernel/linux-rockchip64-edge.config";
    hash = "sha256-IWDzY/Y0Ou1TfFa1A9DxrXDAnE9ptpFZAeGrJgUKT38=";
  };

  kernelPatches =
    linux_7_3.kernelPatches
    ++ lib.concatMap lib.patchesIn [
      ../patches/kernel/7.3
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
