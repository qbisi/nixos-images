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

    colmena =
      (lib.packagesFromDirectoryRecursive {
        callPackage = path: _: {
          imports = [
            path
            self.nixosModules.default
          ];
        };
        directory = ./by-name;
      })
      // {
        meta = {
          nixpkgs = import inputs.nixpkgs { system = "x86_64-linux"; };
          machinesFile = "/etc/nix/machines";
          specialArgs = {
            inherit inputs self lib;
          };
        };
      };

    colmenaHive = inputs.colmena.lib.makeHive self.colmena;
  };
}
