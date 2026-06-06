{
  config,
  pkgs,
  lib,
  self,
  ...
}:
{
  imports = [
    ../../devices/by-name/nixos-xunlong-orangepi-5-plus.nix
    ../../profiles/desktop.nix
    ../../profiles/common.nix
  ];
}
