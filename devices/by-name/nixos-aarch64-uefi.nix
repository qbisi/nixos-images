{
  imports = [
    ../common.nix
  ];

  nixpkgs = {
    system = "aarch64-linux";
  };

  disko = {
    bootImage.fileSystem = "btrfs";
  };
}
