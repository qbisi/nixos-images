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

  networking.hostName = lib.mkDefault "e88a";

  hardware = {
    deviceTree = {
      name = "rockchip/rk3588-jwipc-e88a.dtb";
      platform = "rockchip";
      dtsFile = ../../dts/mainline/rk3588-jwipc-e88a.dts;
    };
  };
}
