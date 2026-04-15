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
          let
            nixosSystem = lib.nixosSystem {
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
            };
          in
          nixosSystem.config.system.build.diskoImages
          // lib.optionalAttrs (nixosSystem.config.hardware.deviceTree.dtsFile != null) {
            dtb = nixosSystem.config.hardware.deviceTree.package;
            uboot = nixosSystem.config.disko.bootImage.uboot.package;
          };
        directory = ./by-name;
      };
    };
}
