{
  inputs,
  ...
}:
{
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
            ./system/grow-partition.nix
            ./config/passless.nix
            ./services/rsync-nixosconfig.nix
          ];

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
