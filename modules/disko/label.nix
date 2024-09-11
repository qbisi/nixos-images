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
      default = "main";
      example = "usb";
      type = types.str;
      description = ''
        System disk label.
        Used for image name creation.
      '';
    };
    disko.device = mkOption {
      default = "/dev/disk/by-diskseq/1";
      example = "/dev/sda";
      type = types.str;
      description = ''
        System disk device.
        Used for grub-install.
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
