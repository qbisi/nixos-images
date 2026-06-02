{
  lib,
  self,
  inputs,
  ...
}:
{
  flake = {
    nixosModules = {
      default = {
        disabledModules = [
          "system/boot/loader/grub/grub.nix"
          "hardware/device-tree.nix"
          __curPos.file
        ];

        imports = [
          inputs.disko.nixosModules.default
        ]
        ++ lib.filter (p: lib.hasSuffix ".nix" p) (lib.filesystem.listFilesRecursive ./.);

        nixpkgs.overlays = [
          self.overlays.default
          (import ../overlays.nix)
        ];
      };
    };
  };
}
