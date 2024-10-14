{ config
, pkgs
, lib
, modulesPath
, inputs
, self
, ...
}:
{
  nixpkgs.system = "x86_64-linux";

  disko = {
    enableConfig = true;
    profile.use = "btrfs";
  };

  hardware = {
    serial.enable = true;
  };

  boot = {
    kernelParams = [
      "net.ifnames=0"
    ];
    loader.grub.enable = true;
  };

}
