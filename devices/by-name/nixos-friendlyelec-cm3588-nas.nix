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

  networking.hostName = lib.mkDefault "cm3588";

  hardware = {
    deviceTree = {
      name = "rockchip/rk3588-friendlyelec-cm3588-nas.dtb";
      platform = "rockchip";
      dtsFile = ../../dts/mainline/rockchip/rk3588-friendlyelec-cm3588-nas.dts;
    };
  };
}
