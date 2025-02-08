{
  self,
  inputs,
  lib,
  ...
}:
let
  x86_64-devices = lib.filesystem.listFilesRecursive ./x86_64-linux;
  aarch64-devices = lib.filesystem.listFilesRecursive ./aarch64-linux;
  all-devices = lib.listToAttrs (
    map (
      path:
      let
        system = baseNameOf (dirOf path);
        name = lib.removeSuffix ".nix" (baseNameOf path);
      in
      lib.nameValuePair name { inherit path system; }
    ) (x86_64-devices ++ aarch64-devices)
  );
in
{
  flake = {
    nixosConfigurations = lib.mapAttrs (
      n: v:
      lib.nixosSystem {
        inherit (v) system;
        specialArgs = {
          inherit inputs self;
          pkgs-self = self.legacyPackages.${v.system};
        };
        modules = [
          {
            disko.profile.imageName = n;
          }
          v.path
          self.nixosModules.default
          self.nixosModules.bootstrap
        ];
      }
    ) all-devices;
    images = lib.mapAttrs (n: v: v.config.system.build.diskoImages) self.nixosConfigurations;
  };
}
