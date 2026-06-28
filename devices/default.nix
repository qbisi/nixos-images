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
          ../profiles/bootstrap.nix
        ];
      };
    directory = ./by-name;
  };

  perSystem =
    {
      pkgs,
      lib,
      ...
    }:
    {
      legacyPackages = lib.packagesFromDirectoryRecursive {
        callPackage =
          path: _:
          let
            device = lib.removeSuffix ".nix" (baseNameOf path);
            nixosSystem = self.nixosConfigurations."${device}".extendModules {
              modules = [
                {
                  disko.imageBuilder.pkgs = pkgs.extend (import ../overlays.nix);
                }
              ];
            };
          in
          nixosSystem.config.system.build.diskoImages;
        directory = ./by-name;
      };
    };
}
