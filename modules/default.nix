{
  flake = {
    nixosModules = {
      default = {
        imports = [
          ./all-modules.nix
        ];
      };
    };
  };
}
