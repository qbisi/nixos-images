{
  self,
  inputs,
  lib,
  ...
}:
{
  flake.nixosConfigurations = lib.packagesFromDirectoryRecursive {
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

  perSystem =
    {
      config,
      pkgs,
      lib,
      system,
      ...
    }:
    {
      legacyPackages = lib.packagesFromDirectoryRecursive {
        callPackage =
          path: _:
          (lib.nixosSystem {
            specialArgs = {
              inherit inputs self;
            };
            modules = [
              {
                disko.bootImage.imageName = lib.removeSuffix ".nix" (baseNameOf path);
                disko.imageBuilder.pkgs = pkgs;
              }
              path
              self.nixosModules.default
              self.nixosModules.bootstrap
            ];
          }).config.system.build.diskoImages;
        directory = ./by-name;
      };
    };
}
