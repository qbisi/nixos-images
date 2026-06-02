{
  imports = [
    ../common.nix
    ../btrfs.nix
  ];

  nixpkgs = {
    system = "x86_64-linux";
  };
}
