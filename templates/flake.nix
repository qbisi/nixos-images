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
  };

  outputs =
    { self, nixpkgs, ... }@inputs:
    {
      nixosConfigurations = nixpkgs.lib.packagesFromDirectoryRecursive {
        callPackage =
          path: _:
          nixpkgs.lib.nixosSystem {
            specialArgs = {
              inherit inputs self;
            };
            modules = [
              path
              inputs.nixos-images.nixosModules.default
            ];
          };
        directory = ./hosts;
      };
    };
}
