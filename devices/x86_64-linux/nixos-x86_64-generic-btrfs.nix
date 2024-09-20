{ config
, pkgs
, lib
, modulesPath
, inputs
, self
, ...
}:
{
  imports = [
    ./nixos-x86_64-uefi-btrfs.nix
  ];

  disko.profile.enableBiosBoot = true;
  boot.loader.grub.device = "/dev/disk/by-diskseq/1";
}