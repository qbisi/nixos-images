{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ../rockchip-rk3588.nix
    ../common.nix
  ];

  networking.hostName = lib.mkDefault "v1a";

  disko = {
    enableConfig = true;
    bootImage = {
      fileSystem = "btrfs";
    };
  };

  hardware = {
    deviceTree = {
      name = "rockchip/rk3588-ido-evb3588-v1a.dtb";
      platform = "rockchip";
      dtsFile = ../../dts/mainline/rk3588-ido-evb3588-v1a.dts;
    };
  };
}
