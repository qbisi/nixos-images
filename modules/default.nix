{ inputs
, ...
}: {
  flake = {
    nixosModules = {
      default = {
        disabledModules = [ "system/boot/loader/grub/grub.nix" ];

        imports = [
          ./disko/profile.nix
          ./disko/btrfs.nix
          ./overlay/system/boot/loader/grub.nix
          ./system/loader.nix
          inputs.disko.nixosModules.default
        ];
      };
      bootstrap = { config, pkgs, ... }: {
        imports = [
          ./config/networking.nix
          ./system/grow-partition.nix
          ./config/passless.nix
        ];

        environment.systemPackages = with pkgs; [
          vim
          grub2_efi
        ];

        system.stateVersion = config.system.nixos.release;
      };
    };
  };
}
