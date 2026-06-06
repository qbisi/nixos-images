{
  config,
  pkgs,
  lib,
  self,
  ...
}:
{
  imports = [
    ../../devices/by-name/nixos-firefly-aio-3588q.nix
    ../../profiles/desktop.nix
    ../../profiles/common.nix
  ];
}
