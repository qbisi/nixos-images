{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-images.url = "github:qbisi/nixos-images";
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
    inputs.flake-parts.lib.mkFlake { inherit inputs; } (
      { lib, self, ... }:
      {
        systems = [
          "aarch64-linux"
        ];
        imports = [
          inputs.flake-parts.flakeModules.easyOverlay
          ./devices
          ./hosts
          ./modules
        ];

        flake.hydraJobs = {
          inherit (self) images packages;
        };

        perSystem =
          {
            config,
            pkgs,
            lib,
            system,
            self',
            ...
          }:
          {
            _module.args = {
              pkgs = import inputs.nixpkgs {
                inherit system;
                config = {
                  allowUnfree = true;
                };
              };
            };

            formatter = pkgs.nixfmt-rfc-style;

            overlayAttrs = config.legacyPackages;

            legacyPackages = lib.makeScope pkgs.newScope (
              self:
              (lib.packagesFromDirectoryRecursive {
                inherit (self) callPackage makePatch;
                directory = ./pkgs;
              })
              // (import ./overlays.nix self pkgs)
            );

            packages = lib.packagesFromDirectoryRecursive {
              inherit (self'.legacyPackages) callPackage;
              directory = ./pkgs;
            };
          };
      }
    );
}
