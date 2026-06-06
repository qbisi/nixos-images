{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ../../devices/by-name/nixos-x86_64-uefi.nix
  ];

  virtualisation.hypervGuest.enable = true;

  networking.hostName = "azure-b1s";

  swapDevices = [
    {
      device = "/swap/swapfile";
      size = 1024;
    }
  ];
}
