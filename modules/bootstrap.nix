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
    ./config/passless.nix
    ./system/grow-partition.nix
  ];

  nixpkgs.flake = {
    setFlakeRegistry = false;
    setNixPath = false;
  };

  boot = {
    bcache.enable = lib.mkDefault false;
    loader.grub.btrfsPackage = config.disko.imageBuilder.pkgs.btrfs-progs;
    growPartition.enable = true;
    initrd.availableKernelModules = [
      "mpt3sas"
      "hv_storvsc"
    ];
  };

  hardware.enableAllHardware = lib.mkDefault config.boot.kernelPackages.kernel.configfile.autoModules;

  networking = {
    firewall.enable = false;
    useNetworkd = true;
  };

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  system.stateVersion = config.system.nixos.release;
}
