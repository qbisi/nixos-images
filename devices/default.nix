{
  lib,
  self,
  inputs,
  ...
}:
{
  flake = rec {
    nixosConfigurations = lib.packagesFromDirectoryRecursive {
      callPackage =
        path: _:
        lib.nixosSystem {
          specialArgs = {
            inherit inputs self;
          };
          modules = [
            {
              disko.bootImage.imageName = lib.removeSuffix ".nix" (baseNameOf path);
            }
            path
            self.nixosModules.default
            self.nixosModules.bootstrap
          ];
        };
      directory = ./by-name;
    };
    images = lib.mapAttrs (n: v: v.config.system.build.diskoImages) nixosConfigurations;
  };
}
