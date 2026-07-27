{
  nixConfig = {
    extra-substituters = [
      "https://qbisi.cachix.org"
    ];
    extra-trusted-public-keys = [
      "qbisi.cachix.org-1:FUbVbR4ivzvO+Dxu88VHuTbOT7zfH75rRnTn4dZB8+g="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
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
      inputs.stable.follows = "nixpkgs";
    };
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake {
      inherit inputs;
      specialArgs = {
        lib = inputs.nixpkgs.lib.extend (lib: _: import ./lib.nix lib);
      };
    } (
      {
        self,
        ...
      }:
      {
        systems = [
          "x86_64-linux"
          "aarch64-linux"
        ];

        imports = [
          ./devices
          ./modules
          ./hosts
        ];

        flake = {
          overlays.default = final: prev: self.packages."${prev.stdenv.hostPlatform.system}" or { };
        };

        perSystem =
          {
            config,
            pkgs,
            lib,
            system,
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

            legacyPackages = lib.makeScope (scope: pkgs.newScope ({ inherit lib; } // scope)) (
              self:
              (lib.packagesFromDirectoryRecursive {
                inherit (self) callPackage;
                directory = ./pkgs;
              })
              // (import ./overlays.nix self pkgs)
            );

            packages = lib.packagesFromDirectoryRecursive {
              inherit (config.legacyPackages) callPackage;
              directory = ./pkgs;
            };

            hydraJobs = {
              packages = lib.optionalAttrs (system == "aarch64-linux") config.packages;
            };
          };

        transposition.hydraJobs.adHoc = true;
      }
    );
}
