{
  config,
  pkgs,
  lib,
  self,
  ...
}:
{
  imports = [
    ../../devices/by-name/nixos-jwipc-e88a.nix
    ../../profiles/desktop.nix
    ../../profiles/common.nix
  ];
}
