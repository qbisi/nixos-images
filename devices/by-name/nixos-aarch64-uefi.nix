{
  imports = [
    ../../profiles/btrfs.nix
  ];

  nixpkgs = {
    system = "aarch64-linux";
  };
}
