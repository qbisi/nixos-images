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

      imageFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "U-Boot image file in the package to write into the disk image.";
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
        message = "disko.bootImage.uboot.package should not be null";
      }
      {
        assertion = cfg.uboot.imageFile != null;
        message = "disko.bootImage.uboot.imageFile should not be null";
      }
    ];

    disko.imageBuilder.extraPostVM =
      let
        diskoCfg = config.disko;
        imageName = "${diskoCfg.bootImage.imageName}.${diskoCfg.imageBuilder.imageFormat}";
        assetPrefix = diskoCfg.bootImage.imageName;
      in
      lib.mkBefore ''
        for src in ${cfg.uboot.package}/*; do
          [ -f "$src" ] || continue
          name="$(basename "$src")"
          cp -a "$src" "$out/${assetPrefix}-$name"
        done
        ${config.disko.imageBuilder.pkgs.coreutils}/bin/dd of="$out/${imageName}" if="${cfg.uboot.package}/${cfg.uboot.imageFile}" seek=${toString cfg.uboot.seek} conv=notrunc
      '';
  };
}
