{
  config,
  pkgs,
  lib,
  self,
  ...
}:
{
  imports = [
    ../../devices/by-name/nixos-friendlyelec-cm3588-nas.nix
    ../../profiles/desktop.nix
    ../../profiles/common.nix
  ];
}
