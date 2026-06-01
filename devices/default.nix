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
          ./bootstrap.nix
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
                  boot.loader.grub.btrfsPackage = pkgs.btrfs-progs;
                }
                path
                self.nixosModules.default
                ./bootstrap.nix
              ];
            };
          in
          nixosSystem.config.system.build.diskoImages;
        directory = ./by-name;
      };
    };
}
