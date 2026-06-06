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

  networking.hostName = lib.mkDefault "o5p";

  disko = {
    bootImage = {
      partLabel = lib.mkDefault "NVME";
      uboot = {
        enable = false;
        package = pkgs.buildUBootRk3588 {
          withSpi = true;
          dtsFile = config.hardware.deviceTree.dtsFile;
        };
      };
    };
  };

  hardware = {
    deviceTree = {
      name = "rockchip/rk3588-orangepi-5-plus.dtb";
      platform = "rockchip";
      dtsFile = ../../dts/mainline/rockchip/rk3588-orangepi-5-plus.dts;
    };
  };
}
