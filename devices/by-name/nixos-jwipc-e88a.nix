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
  ];

  networking.hostName = lib.mkDefault "e88a";

  hardware = {
    deviceTree = {
      name = "rockchip/rk3588-jwipc-e88a.dtb";
      platform = "rockchip";
      dtsFile = ../../dts/mainline/rk3588-jwipc-e88a.dts;
    };
  };
}
