{ self
, inputs
, lib
, ...
}:
let
  inherit (lib) nixosSystem mapAttrs mapCartesianProduct cartesianProduct;
  inherit (self.lib) genAttrs' listNixName;
  x86_64-devices = cartesianProduct {
    name = listNixName "${self}/devices/x86_64-linux";
    system = [ "x86_64-linux" ];
  };
  aarch64-devices = cartesianProduct {
    name = listNixName "${self}/devices/aarch64-linux";
    system = [ "aarch64-linux" ];
  };
  images = x86_64-devices ++ aarch64-devices;
in
{
  flake = {
    nixosConfigurations = genAttrs' images (
      image: (nixosSystem {
        system = image.system;
        specialArgs = {
          inherit inputs self;
          pkgs-self = self.legacyPackages.${image.system};
        };
        modules = [
          {
            disko.profile.imageName = image.name;
          }
          "${self}/devices/${image.system}/${image.name}.nix"
          self.nixosModules.default
          self.nixosModules.bootstrap
        ];
      })
    );
    images = mapAttrs (name: value: value.config.system.build.diskoImages)
      self.nixosConfigurations;
  };
}
