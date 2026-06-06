{
  config,
  pkgs,
  lib,
  self,
  ...
}:
{
  imports = [
    ../../devices/by-name/nixos-ido-evb3588-v1a.nix
    ../../profiles/desktop.nix
    ../../profiles/common.nix
  ];
}
