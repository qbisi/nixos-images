{
  config,
  pkgs,
  lib,
  self,
  inputs,
  ...
}:
{
  imports = [
    "${inputs.nixos-images}/devices/by-name/nixos-x86_64-uefi.nix"
  ];

  boot.initrd.availableKernelModules = [ "sd_mod" ];

  virtualisation.hypervGuest.enable = true;

  users.users.root = {
    # use mkpasswd to generate hashedPassword
    # hashedPassword = "$y$j9T$20Q2FTEqEYm1hzP10L1UA.$HLsxMJKmYnIHM2kGVJrLHh0dCtMz.TSVlWb0S2Ja29C";
    openssh.authorizedKeys.keys = [ ];
  };

  networking.hostName = "azure-b1s";

  swapDevices = [
    {
      device = "/swap/swapfile";
      size = 1024;
    }
  ];

  system.stateVersion = "26.05";
}
