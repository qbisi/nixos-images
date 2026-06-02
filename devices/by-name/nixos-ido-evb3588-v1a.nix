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

  networking.hostName = lib.mkDefault "v1a";

  hardware = {
    deviceTree = {
      name = "rockchip/rk3588-ido-evb3588-v1a.dtb";
      platform = "rockchip";
      dtsFile = ../../dts/mainline/rk3588-ido-evb3588-v1a.dts;
    };
  };
}
