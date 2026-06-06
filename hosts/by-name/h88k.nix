{
  config,
  pkgs,
  lib,
  self,
  ...
}:
{
  imports = [
    ../../devices/by-name/nixos-hinlink-h88k.nix
    ../../profiles/desktop.nix
    ../../profiles/common.nix
  ];
}
