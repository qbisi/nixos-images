{
  lib,
  fetchurl,
  fetchFromGitHub,
  buildLinux,
  linux_7_0,
  ...
}:
buildLinux {
  inherit (linux_7_0) version src;

  defconfigFile = fetchurl {
    url = "https://raw.githubusercontent.com/armbian/build/39fdcef4ceda49b6967e9e16b187119ec8ad0336/config/kernel/linux-rockchip64-edge.config";
    hash = "sha256-VKM1wy4oVNvB8gInkRELNiEapkB3KC+ts9E+b5Xuty8=";
  };

  kernelPatches = map (p: {
    name = baseNameOf p;
    patch = p;
  }) (lib.filesystem.listFilesRecursive ../patches/kernel);

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
