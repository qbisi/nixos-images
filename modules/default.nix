{
  flake = {
    nixosModules = {
      default = {
        imports = [
          ./all-modules.nix
        ];
      };
      hybrid-btrfs = ./disko/hybrid-btrfs.nix;
    };
  };
}
