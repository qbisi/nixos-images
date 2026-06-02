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

  networking.hostName = lib.mkDefault "f88q";

  disko = {
    enableConfig = true;
    bootImage = {
      fileSystem = "btrfs";
    };
  };

  hardware = {
    deviceTree = {
      name = "rockchip/rk3588-firefly-aio-3588q.dtb";
      platform = "rockchip";
      dtsFile = ../../dts/mainline/rk3588-firefly-aio-3588q.dts;
    };
  };
}
