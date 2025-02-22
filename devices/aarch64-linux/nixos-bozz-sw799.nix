{
  config,
  pkgs,
  pkgs-self,
  lib,
  modulesPath,
  inputs,
  self,
  ...
}:
let
  system = "aarch64-linux";
in
{
  nixpkgs.system = system;

  networking.hostName = lib.mkDefault "sw799";

  disko = {
    memSize = 4096;
    enableConfig = true;
    profile.use = "btrfs";
    profile.espStart = "16M";
    profile.uboot.enable = true;
    profile.uboot.package = pkgs-self.ubootBozzSW799;
  };

  hardware = {
    firmware = [ pkgs-self.brcmfmac_sdio-firmware ];
    serial = {
      enable = true;
      unit = 2;
      baudrate = 1500000;
    };
  };

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    kernelParams = [
      "net.ifnames=0"
      "console=tty1"
      "earlycon"
    ];
    loader.grub.enable = true;
  };

}
