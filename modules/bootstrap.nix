{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./config/passless.nix
    ./config/rsync-nixosconfig.nix
    ./system/grow-partition.nix
  ];

  boot = {
    loader.grub.btrfsPackage = config.disko.imageBuilder.pkgs.btrfs-progs;
    growPartition.enable = true;
    initrd.availableKernelModules = [
      "mpt3sas"
      "hv_storvsc"
    ];
  };

  hardware.enableAllHardware = lib.mkDefault true;

  networking = {
    firewall.enable = false;
    useNetworkd = true;
  };

  environment.systemPackages = with pkgs; [
    grub2_efi
  ];

  documentation.enable = false;

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  system.stateVersion = config.system.nixos.release;
}
