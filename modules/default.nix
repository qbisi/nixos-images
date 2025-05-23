{
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
          ./config/nixpkgs.nix
          ./disko/disk-image.nix
          ./hardware/serial.nix
          ./overlay/system/boot/loader/grub.nix
          ./overlay/hardware/device-tree.nix
          inputs.disko.nixosModules.default
        ];
      };
      bootstrap =
        {
          config,
          pkgs,
          modulesPath,
          ...
        }:
        {
          imports = [
            "${modulesPath}/profiles/all-hardware.nix"
            ./config/networking.nix
            ./config/passless.nix
            ./config/rsync-nixosconfig.nix
            ./system/grow-partition.nix
          ];

          boot.loader.grub.btrfsPackage = config.disko.imageBuilder.pkgs.btrfs-progs;

          boot.initrd.availableKernelModules = [
            "mpt3sas"
            "hv_storvsc"
          ];

          environment.systemPackages = with pkgs; [
            vim
            grub2_efi
          ];

          nix.settings = {
            experimental-features = [
              "nix-command"
              "flakes"
            ];
          };

          system.stateVersion = config.system.nixos.release;
        };
    };
  };
}
