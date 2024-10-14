{ config, lib, pkgs, ... }:
with lib;
let cfg = config.disko.profile;
in
{
  options = {
    disko.profile.uboot = {
      enable = mkEnableOption "uboot part in disk";

      package = mkOption
        {
          type = types.nullOr types.package;
          default = null;
        };
    };
  };

  config = mkIf (cfg.use != "" && cfg.uboot.enable) {
    assertions = [
      {
        assertion = cfg.uboot.package != null;
        message = "disko.profile.uboot.pacakges should not be null";
      }
    ];

    disko.imageBuilder.extraPostVM =
      let
        diskoCfg = config.disko;
        imageName = "${diskoCfg.devices.disk.main.imageName}.${diskoCfg.imageBuilder.imageFormat}";
      in
      mkBefore ''
        ${pkgs.coreutils}/bin/dd of=$out/${imageName} if=${cfg.uboot.package}/u-boot-rockchip.bin bs=4K seek=8 conv=notrunc
      '';
  };
}
