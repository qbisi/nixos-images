{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ../../profiles/rk3588.nix
    ../../profiles/btrfs.nix
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
