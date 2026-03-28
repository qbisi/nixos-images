{
  lib,
  buildLinux,
  fetchFromGitHub,
  fetchpatch,
  armbianBuild,
  linux_6_18,
  ...
}:
let
  defconfigFile = "${armbianBuild}/config/kernel/linux-rockchip64-current.config";
  patchDir = "${armbianBuild}/patch/kernel/archive/rockchip64-6.18";
  disabledPatches = [
    "general-rk3588-i2s-mclk-output-gate-1-bindings.patch"
    "general-rk3588-i2s-mclk-output-gate-2-allow-grf-type-sys.patch"
    "general-rk3588-i2s-mclk-output-gate-3-grf-header.patch"
    "general-rk3588-i2s-mclk-output-gate-4-gate-grf-clocks.patch"
  ];
  kernelPatches =
    (map (p: {
      name = baseNameOf p;
      patch = p;
    }) (lib.filesystem.listFilesRecursive patchDir))
    ++ [
      {
        name = "add-typec-husb311";
        patch = ../patches/kernel/add-husb311.patch;
      }
    ];
  filteredPatches = lib.filter (p: !(builtins.elem p.name disabledPatches)) kernelPatches;
  structuredExtraConfig = with lib.kernel; {
    # FW_LOADER
    FW_LOADER_COMPRESS = yes;
    FW_LOADER_COMPRESS_ZSTD = yes;
    # PCIE PHY
    PHY_ROCKCHIP_SNPS_PCIE3 = yes;
    # MMC
    MMC_BLOCK = yes;
    # MPTCP
    MPTCP = yes;
    INET_MPTCP_DIAG = module;
  };
in
buildLinux {
  inherit (linux_6_18)
    version
    src
    ;
  inherit
    defconfigFile
    structuredExtraConfig
    ;
  kernelPatches = filteredPatches;
  enableCommonConfig = false;
  extraConfig = "";
  ignoreConfigErrors = true;
  autoModules = false;
  extraMakeFlags = [ "KCFLAGS=-march=armv8-a+crypto" ];
}
