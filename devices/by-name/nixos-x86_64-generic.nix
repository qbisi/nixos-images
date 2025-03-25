{
  imports = [
    ./nixos-x86_64-uefi.nix
  ];

  disko.bootImage.enableBiosBoot = true;
  boot.loader.grub.device = "/dev/disk/by-diskseq/1";
}
