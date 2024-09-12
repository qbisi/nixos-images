{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
{
  options = {
    disko.label = mkOption {
      default = "";
      example = "nixos-x86_64-generic-btrfs";
      type = types.str;
      description = ''
        System disk label.
        Used for image name creation.
      '';
    };
    disko.type = mkOption {
      default = "scsi";
      example = "nvme";
      type = types.str;
      description = ''
        System disk type.
        Used for image name creation.
      '';
    };
  };

  config = {
    disko = {
      extraPostVM = ''
        mv $out/*.raw "$out/${config.disko.label}-${config.disko.type}.raw"
        ${pkgs.xz}/bin/xz -z $out/*.raw
      '';
    };
  };
}
