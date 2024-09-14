{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./disko/label.nix
    ./system/grow-partition.nix
  ];
  system.stateVersion = config.system.nixos.release;
}
