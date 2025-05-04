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
    nixos-images.url = "github:qbisi/nixos-images";
    colmena = {
      url = "github:zhaofengli/colmena";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, nixpkgs, ... }@inputs:
    {
      nixosConfigurations = {
        azure-b1s = nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit inputs self;
          };
          modules = [
            inputs.nixos-images.nixosModules.default
            inputs.colmena.nixosModules.deploymentOptions
            "${inputs.nixos-images}/devices/by-name/nixos-x86_64-uefi.nix"
            # ./path-to-your-custom-config
          ];
        };

        opi5-plus = nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit inputs self;
          };
          modules = [
            inputs.nixos-images.nixosModules.default
            inputs.colmena.nixosModules.deploymentOptions
            "${inputs.nixos-images}/devices/by-name/nixos-xunlong-orangepi-5-plus.nix"
            # ./path-to-your-custom-config
          ];
        };
      };

      colmena = {
        meta = {
          nixpkgs = import inputs.nixpkgs { system = "x86_64-linux"; };
          specialArgs = {
            inherit inputs self;
          };
        };

        azure-b1s = {
          imports = [
            inputs.nixos-images.nixosModules.default
            "${inputs.nixos-images}/devices/by-name/nixos-x86_64-uefi.nix"
            # ./path-to-your-custom-config
          ];
        };

        opi5-plus = {
          imports = [
            inputs.nixos-images.nixosModules.default
            "${inputs.nixos-images}/devices/by-name/nixos-xunlong-orangepi-5-plus.nix"
            # ./path-to-your-custom-config
          ];
        };
      };
    };
}
