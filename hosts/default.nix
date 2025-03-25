{
  lib,
  inputs,
  self,
  ...
}:
{
  flake = {
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
            inputs.colmena.nixosModules.deploymentOptions
          ];
        };
      directory = ./by-name;
    };
  };
}
