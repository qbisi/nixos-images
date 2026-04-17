{
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
        ];

        imports = [
          ./disko/disk-image.nix
          ./hardware/serial.nix
          ./overlay/system/boot/loader/grub.nix
          ./overlay/hardware/device-tree.nix
          ./desktop-managers/plasma6.nix
          inputs.disko.nixosModules.default
        ];

        nixpkgs.overlays = [
          self.overlays.default
          (import ../overlays.nix)
        ];
      };
      bootstrap = import ./bootstrap.nix;
    };
  };
}
