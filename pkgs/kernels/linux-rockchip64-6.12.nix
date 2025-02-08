{
  lib,
  buildLinux,
  fetchurl,
  fetchFromGitHub,
  makePatch,
  linux_6_12,
  ...
}:
let
  armbianBuild = fetchFromGitHub {
    owner = "qbisi";
    repo = "build";
    rev = "d86616fd67c980e4d1df48232e826f20d6f72fbf";
    nonConeMode = true;
    sparseCheckout = [
      "config/kernel/*.config"
      "patch/kernel/**/*.patch"
    ];
    hash = "sha256-OQpdLcTo83c+ZUy0fNTNelKxCoyWeF1Zj4S0Q4CAt+k=";
  };
  defconfigFile = "${armbianBuild}/config/kernel/linux-rockchip64-current.config";
  patchDir = "${armbianBuild}/patch/kernel/archive/rockchip64-6.12";
  kernelPatches = (
    map (p: {
      name = baseNameOf p;
      patch = p;
    }) (lib.filesystem.listFilesRecursive patchDir)
  );
  structuredExtraConfig = with lib.kernel; {
    # hdmi display phy
    PHY_ROCKCHIP_SAMSUNG_HDPTX = yes;
    # pcie phy
    PHY_ROCKCHIP_SNPS_PCIE3 = yes;
  };
in
linux_6_12.override {
  inherit
    defconfigFile
    kernelPatches
    structuredExtraConfig
    ;
  ignoreConfigErrors = true;
  autoModules = true;
}
