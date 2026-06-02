{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.disko.bootImage;
in
{
  options = {
    disko.bootImage.uboot = {
      enable = lib.mkEnableOption "uboot part in disk";

      package = lib.mkOption {
        type = lib.types.nullOr lib.types.package;
        default = null;
      };

      seek = lib.mkOption {
        type = lib.types.number;
        default = 0;
      };
    };
  };

  config = lib.mkIf (cfg.primaryContent != null && cfg.uboot.enable) {
    assertions = [
      {
        assertion = cfg.uboot.package != null;
        message = "disko.bootImage.uboot.pacakges should not be null";
      }
    ];

    disko.imageBuilder.extraPostVM =
      let
        diskoCfg = config.disko;
        imageName = "${diskoCfg.devices.disk.main.imageName}.${diskoCfg.imageBuilder.imageFormat}";
      in
      lib.mkBefore ''
        ${config.disko.imageBuilder.pkgs.coreutils}/bin/dd of=$out/${imageName} if=${cfg.uboot.package}/u-boot-rockchip.bin seek=${toString cfg.uboot.seek} conv=notrunc
      '';
  };
}
