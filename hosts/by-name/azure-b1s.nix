{
  config,
  pkgs,
  lib,
  self,
  inputs,
  ...
}:
{
  deployment = {
    buildOnTarget = true;
    tags = [ "vps" ];
  };

  imports = [
    "${self}/devices/by-name/nixos-x86_64-uefi.nix"
  ];

  boot.initrd.availableKernelModules = [ "sd_mod" ];

  virtualisation.hypervGuest.enable = true;

  networking.hostName = "azure-b1s";

  swapDevices = [
    {
      device = "/swap/swapfile";
      size = 1024;
    }
  ];

  system.stateVersion = "24.11";
}
