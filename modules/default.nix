{
  flake = {
    nixosModules = {
      default = {
        imports = [
          ./all-modules.nix
        ];
      };
      btrfs = ./disko/btrfs.nix;
    };
  };
}
