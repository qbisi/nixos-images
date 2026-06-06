{
  config,
  pkgs,
  lib,
  self,
  ...
}:
{
  imports = [
    ../../devices/by-name/nixos-radxa-rock-5t.nix
    ../../profiles/desktop.nix
    ../../profiles/common.nix
  ];
}
