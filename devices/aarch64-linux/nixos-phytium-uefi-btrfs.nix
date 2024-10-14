{ config
, pkgs
, pkgs-self
, lib
, modulesPath
, inputs
, self
, ...
}:
let
  system = "aarch64-linux";
in
{
  nixpkgs.system = system;

  disko = {
    memSize = 4096;
    enableConfig = true;
    profile.use = "btrfs";
    profile.partLabel = "nvme";
  };

  hardware = {
    serial.enable = true;
  };

  boot = {
    kernelPackages = pkgs.linuxPackagesFor pkgs-self.linux_phytium_6_6;
    kernelParams = [
      "net.ifnames=0"
      "console=tty1"
      "earlycon"
    ];
    loader.grub.enable = true;
  };

}
