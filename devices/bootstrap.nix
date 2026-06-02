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
      # extraPostVM = lib.mkAfter ''
      #   ${config.disko.imageBuilder.pkgs.xz}/bin/xz -z $out/*${config.disko.imageBuilder.imageFormat}
      # '';
    };

    bootImage = {
      imageSize = "2G";
      partLabel = lib.mkIf (builtins.getEnv "PARTLABEL" != "") (builtins.getEnv "PARTLABEL");
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

  hardware.enableAllHardware = lib.mkDefault config.boot.kernelPackages.kernel.configfile.autoModules;

  services = {
    # usb-rndis.enable = true;
  };
}
