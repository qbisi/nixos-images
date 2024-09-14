{
  config,
  pkgs,
  lib,
  modulesPath,
  inputs,
  self,
  ...
}:
{
  imports = [
    ./nixos-x86_64-uefi-btrfs.nix
  ];

  disko.biosboot.enable = true;
  boot.loader.grub.device = "/dev/disk/by-diskseq/1";
}
