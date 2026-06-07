{
  config,
  pkgs,
  lib,
  self,
  ...
}:
{
  imports = [
    ../../devices/by-name/nixos-radxa-rock-5-itx.nix
    ../../profiles/desktop.nix
    ../../profiles/common.nix
  ];
}
