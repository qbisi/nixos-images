{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    disko = {
      # url = "github:nix-community/disko";
      url = "github:qbisi/disko/develop";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      imports = [
        ./devices
        ./lib
        ./modules
        ./pkgs
      ];
      perSystem =
        { config, pkgs, ... }:
        {
          formatter = pkgs.nixpkgs-fmt;
        };
    };
}
