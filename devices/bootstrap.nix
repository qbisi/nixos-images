{
  config,
  lib,
  modulesPath,
  ...
}:
{
  imports = [
    "${modulesPath}/profiles/minimal.nix"
  ];

  system = {
    passless.enable = true;
    symlinkConfig.enable = true;
  };

  disko = {
    memSize = lib.mkDefault 4096;

    imageBuilder = {
      enableBinfmt = true;
      kernelPackages = config.disko.imageBuilder.pkgs.linuxPackages;
    };

    bootImage = {
      imageSize = "2G";
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
}
