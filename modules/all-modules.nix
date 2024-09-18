{ config
, lib
, pkgs
, inputs
, ...
}:
{
  imports = [
    ./disko/profile.nix
    ./disko/btrfs.nix
    ./system/grow-partition.nix
    ./system/loader.nix
    inputs.disko.nixosModules.default
  ];
  system.stateVersion = config.system.nixos.release;
}
