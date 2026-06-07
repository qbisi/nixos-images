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

  networking.hostName = lib.mkDefault "r5itx";

  disko = {
    bootImage = {
      partLabel = lib.mkDefault "NVME";
      primaryStart = "1M";
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
      name = "rockchip/rk3588-rock-5-itx.dtb";
      platform = "rockchip";
      dtsFile = ../../dts/mainline/rockchip/rk3588-rock-5-itx.dts;
    };
  };
}
