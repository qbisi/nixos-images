{
  self,
  inputs,
  lib,
  ...
}:
with lib;
let
  device = [
    "nixos-x86_64-generic-btrfs"
  ];
  diskType = [
    "mmc"
    "sd"
    "usb"
    "nvme"
    "scsi"
  ];
  imageNames = mapCartesianProduct ({ device, diskType }: "${device}-${diskType}") {
    inherit device diskType;
  };
in
{
  flake = rec {
    nixosConfigurations = listToAttrs (
      mapCartesianProduct (
        { device, diskType }:
        (nameValuePair "${device}-${diskType}" (
          lib.nixosSystem {
            specialArgs = {
              inherit inputs self;
            };
            modules = [
              { disko.type = diskType; disko.label = device; }
              ./${device}.nix
              self.nixosModules.default
              inputs.disko.nixosModules.default
            ];
          }
        ))
      ) { inherit device diskType; }
    );
    images = genAttrs imageNames (
      imageName: nixosConfigurations.${imageName}.config.system.build.diskoImages
    );
  };
}
