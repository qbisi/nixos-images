{
  imports = [
    ../btrfs.nix
    ../common.nix
  ];

  nixpkgs = {
    system = "aarch64-linux";
  };
}
