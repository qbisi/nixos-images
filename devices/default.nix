{ self
, inputs
, lib
, ...
}:
with lib;
let
  inherit (self.lib) genAttrs' listNixName;
  x86_64-devices = cartesianProduct {
    name = listNixName "${self}/devices/x86_64-linux";
    system = [ "x86_64-linux" ];
  };
  aarch64-devices = cartesianProduct {
    name = listNixName "${self}/devices/aarch64-linux";
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
          # system = image.system;
          inherit inputs self;
        };
        modules = [
          {
            disko.profile = {
              partLabel = image.diskType;
              imageName = image.name;
            };
          }
          "${self}/devices/${image.system}/${image.device}.nix"
          self.nixosModules.default
          self.nixosModules.bootstrap
        ];
      })
    );
    images = genAttrs' images (
      image: self.nixosConfigurations.${image.name}.config.system.build.diskoImages
    );
  };
}
