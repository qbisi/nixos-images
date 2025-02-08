{
  inputs = {
    # nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixpkgs.url = "github:qbisi/nixpkgs/kernel-next";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    colmena = {
      url = "github:zhaofengli/colmena";
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
        ./hosts
        ./modules
        ./pkgs
      ];
      perSystem =
        { config, pkgs, ... }:
        {
          formatter = pkgs.nixfmt-rfc-style;
          devShells.default = pkgs.mkShell {
            packages = with pkgs; [ dtc ];
          };
        };
    };
}
