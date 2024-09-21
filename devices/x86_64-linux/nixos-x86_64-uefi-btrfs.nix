{ config
, pkgs
, lib
, modulesPath
, inputs
, self
, ...
}:
{
  imports = [
    (modulesPath + "/profiles/all-hardware.nix")
  ];

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
      "console=tty1"
    ];
    loader.grub.enable = true;
  };

}
