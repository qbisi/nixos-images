{ lib, config, self, inputs, ... }:
{
  perSystem = { config, pkgs, lib, system, ... }: {
    legacyPackages = import ./top-level.nix { inherit pkgs; };
  };
}
