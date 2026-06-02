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

  networking.hostName = lib.mkDefault "f88q";

  hardware = {
    deviceTree = {
      name = "rockchip/rk3588-firefly-aio-3588q.dtb";
      platform = "rockchip";
      dtsFile = ../../dts/mainline/rk3588-firefly-aio-3588q.dts;
    };
  };
}
