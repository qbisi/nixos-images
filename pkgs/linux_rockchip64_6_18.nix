{
  lib,
  fetchurl,
  fetchFromGitHub,
  buildLinux,
  linux_6_18,
  ...
}:
buildLinux {
  inherit (linux_6_18) version src;

  defconfigFile = fetchurl {
    url = "https://raw.githubusercontent.com/armbian/build/559a605841fb02592d8a2db3edd614d80dd236aa/config/kernel/linux-rockchip64-current.config";
    hash = "sha256-E0C+LY5wl20anyKHs+Os13buYdP+0xgxc/DAUXHmZb0=";
  };

  kernelPatches =
    map
      (p: {
        name = baseNameOf p;
        patch = p;
      })
      (
        builtins.filter (p: lib.hasSuffix ".patch" (toString p)) (
          lib.filesystem.listFilesRecursive ../patches/kernel
        )
      );

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
