{
  imports = [
    ../common.nix
  ];

  nixpkgs = {
    system = "x86_64-linux";
  };

  disko = {
    bootImage.fileSystem = "btrfs";
  };
}
