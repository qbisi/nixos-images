{
  nixConfig = {
    extra-substituters = [
      "https://cache.qbisi.cc"
    ];
    extra-trusted-public-keys = [
      "cache.qbisi.cc:agX2YjzMlHUdRAbrzSBh8P42b9J00VYs/FndKjWmnfI="
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
          "i686-linux"
          "x86_64-linux"
          "aarch64-linux"
        ];
        imports = [
          ./devices
          ./hosts
          ./modules
        ];

        flake = {
          overlays.default = final: prev: self.packages."${prev.stdenv.hostPlatform.system}";

          hydraJobs = {
            inherit (self) packages;
          };
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

            legacyPackages = lib.makeScope pkgs.newScope (
              self:
              (lib.packagesFromDirectoryRecursive {
                inherit (self) callPackage;
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
