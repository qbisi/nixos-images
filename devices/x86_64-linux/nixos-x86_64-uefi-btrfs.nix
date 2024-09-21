{ config
, pkgs
, lib
, modulesPath
, inputs
, self
, ...
}:
{
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
