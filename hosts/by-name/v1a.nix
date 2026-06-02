{
  config,
  pkgs,
  lib,
  self,
  ...
}:
{
  imports = [
    "${self}/devices/by-name/nixos-ido-evb3588-v1a.nix"
  ];

  hardware = {
    graphics.enable = true;
  };

  services = {
    cage = {
      enable = true;
      program = "${pkgs.configuration}/bin/configuration";
      user = "root";
    };
  };
}
