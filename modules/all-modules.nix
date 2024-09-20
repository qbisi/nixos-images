{ config
, lib
, pkgs
, inputs
, ...
}:
{
  disabledModules = [ "system/boot/loader/grub/grub.nix" ];

  imports = [
    ./overlay/system/boot/loader/grub.nix
    ./disko/profile.nix
    ./disko/btrfs.nix
    ./system/grow-partition.nix
    ./system/loader.nix
    inputs.disko.nixosModules.default
  ];
  system.stateVersion = config.system.nixos.release;
}
