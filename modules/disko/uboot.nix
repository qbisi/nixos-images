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
    };
  };

  config = lib.mkIf (cfg.fileSystem != null && cfg.uboot.enable) {
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
        ${config.disko.imageBuilder.pkgs.coreutils}/bin/dd of=$out/${imageName} if=${cfg.uboot.package}/u-boot-rockchip.bin bs=4K seek=8 conv=notrunc
      '';
  };
}
