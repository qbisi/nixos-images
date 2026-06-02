{
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ../aarch64-uefi.nix
  ];

  hardware.enableAllHardware = false;

  boot = {
    kernelPackages = lib.mkDefault (pkgs.linuxPackagesFor pkgs.linux_phytium_6_6);
  };
}
