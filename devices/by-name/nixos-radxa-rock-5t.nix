{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ../profiles/rk3588.nix
    ../profiles/btrfs.nix
  ];

  networking.hostName = lib.mkDefault "r5t";

  disko = {
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
