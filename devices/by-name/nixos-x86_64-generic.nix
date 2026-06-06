{
  imports = [
    ./nixos-x86_64-uefi.nix
  ];

  disko.bootImage.enableBiosBoot = true;
}
