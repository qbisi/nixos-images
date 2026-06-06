{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:
{
  imports = [
    "${modulesPath}/profiles/minimal.nix"
  ];

  system = {
    firstLoginSetup.enable = true;
    passless.enable = true;
    symlinkConfig.enable = true;
  };

  disko = {
    imageBuilder = {
      enableBinfmt = config.disko.imageBuilder.pkgs != pkgs;
      kernelPackages = config.disko.imageBuilder.pkgs.linuxPackages;
    };
  };

  boot = {
    growPartition.enable = true;
    espRelocation.enable = true;
    loader.grub.btrfsPackage = config.disko.imageBuilder.pkgs.btrfs-progs;
    initrd.availableKernelModules = lib.mkIf config.hardware.enableAllHardware [
      "mpt3sas"
      "hv_storvsc"
    ];
  };

  hardware.enableAllHardware = lib.mkDefault true;

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
  };
}
