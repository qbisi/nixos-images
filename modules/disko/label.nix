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
      default = "nvme";
      example = "mmc";
      type = types.str;
      description = ''
        System disk label.
        Used for image name creation.
      '';
    };
  };

  config = {
    disko = {
      extraPostVM = ''
        ${pkgs.xz}/bin/xz -z $out/*.raw
      '';
    };
  };
}
