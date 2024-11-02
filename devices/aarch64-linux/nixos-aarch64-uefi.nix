{ config
, pkgs
, pkgs-self
, lib
, modulesPath
, inputs
, self
, ...
}:
{
  nixpkgs.system = "aarch64-linux";

  disko = {
    memSize = 4096;
    enableConfig = true;
    profile.use = "btrfs";
  };

  hardware = {
    serial.enable = true;
  };

  boot = {
    kernelParams = [
      "net.ifnames=0"
      "console=tty1"
      "earlycon"
    ];
    loader.grub.enable = true;
  };

}
