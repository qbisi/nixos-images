{ config, lib, ... }:
with lib;
let cfg = config.disko.profile;
in
{
  options = {
    disko.profile.uboot = {
      enable = mkOption {
        type = types.bool;
        default = builtins.elem config.disko.profile.partLabel [ "mmc" "sd" ];
      };

      package = mkOption
        {
          type = types.nullOr types.pkgs;
          default = null;
        };
    };
  };

  config = mkIf (cfg.use != "" && cfg.uboot.enable) {
    assertions = [
      {
        assertion = cfg.package != null;
        message = "disko.profile.uboot.pacakges should not be null";
      }
    ];

    disko.profile = {
      extraPostVM =
        let
          diskoCfg = config.disko;
          imageName = "${diskoCfg.devices.disk.main.name}.${diskoCfg.imageBuilder.imageFormat}";
        in
        mkBefore ''
          ${pkgs.coreutils}/bin/dd of=$out/${imageName} if=${cfg.uboot.pacakge}/u-boot-rockchip.bin bs=4K seek=8 conv=notrunc
        '';
      espStart = "16M";
    };
  };
}
