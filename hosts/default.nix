{
  self,
  inputs,
  lib,
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
            ({config, ...}: {
              # SSH to llmnr hosts need retry to wait for hostname resolution.
              # Requires colmena version > 0.5.0.
              deployment = {
                targetHost = lib.mkIf config.services.usb-rndis.enable config.services.usb-rndis.ipv4Address;
                sshOptions = [ "-o ConnectionAttempts=2" ];
              };
              system.passless.enable = true;
            })
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
