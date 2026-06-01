{
  config,
  lib,
  modulesPath,
  ...
}:
{
  imports = [
    "${modulesPath}/profiles/minimal.nix"
    ./passless.nix
    ./relocate-esp.nix
  ];

  nixpkgs.flake = {
    setFlakeRegistry = false;
    setNixPath = false;
  };

  boot = {
    growPartition.enable = true;
    initrd.availableKernelModules = lib.mkIf config.hardware.enableAllHardware [
      "mpt3sas"
      "hv_storvsc"
    ];
  };

  hardware.enableAllHardware = lib.mkDefault config.boot.kernelPackages.kernel.configfile.autoModules;

  services = {
    usb-rndis.enable = true;
  };

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
  };
}
