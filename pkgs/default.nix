{ lib, config, self, inputs, ... }:
{
  perSystem = { config, pkgs, lib, system, ... }: {
    packages = import ./top-level.nix { inherit pkgs; };
  };
}
