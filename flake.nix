{
  nixConfig = {
    extra-substituters = [
      "https://cache.qbisi.cc"
    ];
    extra-trusted-public-keys = [
      "cache.qbisi.cc-1:xEChzP5k8fj+7wajY+e9IDORRTGMhViP5NaqMShGGjQ="
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
    };
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } (
      {
        lib,
        self,
        withSystem,
        getSystemIgnoreWarning,
        ...
      }:
      {
        systems = [
          "x86_64-linux"
          "aarch64-linux"
        ];

        imports = [
          ./devices
          ./hosts
          ./modules
        ];

        flake = {
          overlays.default = final: prev: self.packages."${prev.stdenv.hostPlatform.system}" or { };

          templates = {
            default = {
              path = ./templates;
              description = "init template";
            };
          };
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

            legacyPackages = lib.makeScope pkgs.newScope (
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
