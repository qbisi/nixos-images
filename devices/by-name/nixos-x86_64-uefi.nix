{
  imports = [
    ../profiles/btrfs.nix
  ];

  nixpkgs = {
    system = "x86_64-linux";
  };
}
