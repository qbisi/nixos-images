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
                  disko.imageBuilder.pkgs = pkgs.extend (
                    final: prev: {
                      vmTools = prev.vmTools // {
                        override =
                          args:
                          let
                            usesAggregateKernel =
                              args ? kernel
                              && builtins.isAttrs args.kernel
                              && !(args.kernel ? target)
                              && (args.kernel.name or null) == "kernel-modules";
                          in
                          prev.vmTools.override (
                            if usesAggregateKernel then
                              (removeAttrs args [
                                "kernel"
                                "kernelModules"
                              ])
                              // {
                                kernel = prev.linuxPackages.kernel;
                                kernelModules = args.kernelModules or args.kernel;
                              }
                            else
                              args
                          );
                      };
                    }
                  );
                }
              ];
            };
          in
          nixosSystem.config.system.build.diskoImages;
        directory = ./by-name;
      };
    };
}
