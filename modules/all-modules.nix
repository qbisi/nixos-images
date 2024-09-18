{ config
, lib
, pkgs
, ...
}:
{
  imports = [
    ./disko/profile.nix
    ./disko/btrfs.nix
    ./system/grow-partition.nix
    ./system/loader.nix
  ];
  system.stateVersion = config.system.nixos.release;
}
