{ lib, config, self, inputs, ... }:
{
  perSystem = { config, lib, system, ... }: {
    legacyPackages = import ./top-level.nix {
      pkgs = import inputs.nixpkgs {
        inherit system;
      };
    };
  };
}
