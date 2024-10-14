{ inputs
, ...
}: {
  flake = {
    nixosModules = {
      default = {
        disabledModules = [ "system/boot/loader/grub/grub.nix" ];

        imports = [
          ./disko/uboot.nix
          ./disko/profile.nix
          ./disko/btrfs.nix
          ./overlay/system/boot/loader/grub.nix
          ./hardware/serial.nix
          inputs.disko.nixosModules.default
        ];
      };
      bootstrap = { config, pkgs, modulesPath, ... }: {
        imports = [
          "${modulesPath}/profiles/all-hardware.nix"
          ./config/networking.nix
          ./system/grow-partition.nix
          ./config/passless.nix
        ];

        boot.initrd.availableKernelModules = [ "mpt3sas" ];

        environment.systemPackages = with pkgs; [
          vim
          grub2_efi
        ];

        system.stateVersion = config.system.nixos.release;
      };
    };
  };
}
