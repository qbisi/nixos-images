{
  self,
  inputs,
  lib,
  ...
}:
with lib;
with self.lib;
let
  x86_64-devices = cartesianProduct {
    name = listNixname "${self}/devices/x86_64-linux";
    system = [ "x86_64-linux" ];
  };
  aarch64-devices = cartesianProduct {
    name = [ ];
    system = [ "aarch64-linux" ];
  };
  devices = x86_64-devices ++ aarch64-devices;
  diskType = [
    "mmc"
    "sd"
    "usb"
    "nvme"
    "scsi"
  ];
  images =
    mapCartesianProduct
      (
        { devices, diskType }:
        {
          name = "${devices.name}-${diskType}";
          device = devices.name;
          inherit diskType;
          inherit (devices) system;
        }
      )
      {
        inherit devices diskType;
      };
in
{
  flake = {
    nixosConfigurations = genAttrs' images (
      image:
      (lib.nixosSystem {
        system = image.system;
        specialArgs = {
          inherit inputs self;
        };
        modules = [
          {
            disko.type = image.diskType;
            disko.label = image.device;
          }
          ./${image.system}/${image.device}.nix
          self.nixosModules.default
          inputs.disko.nixosModules.default
        ];
      })
    );
    images = genAttrs' images (
      image: self.nixosConfigurations.${image.name}.config.system.build.diskoImages
    );
  };
}
