{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ../rockchip-rk3588.nix
    ../btrfs.nix
    ../common.nix
  ];

  networking.hostName = lib.mkDefault "r5t";

  disko = {
    enableConfig = true;
    bootImage = {
      uboot.package = pkgs.buildUBootRk3588 {
        withSpi = true;
        withNvme = true;
        dtsFile = config.hardware.deviceTree.dtsFile;
      };
    };
  };

  hardware = {
    deviceTree = {
      name = "rockchip/rk3588-rock-5t.dtb";
      platform = "rockchip";
      dtsFile = ../../dts/mainline/rockchip/rk3588-rock-5t.dts;
    };
  };
}
