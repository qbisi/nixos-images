{ config
, pkgs
, lib
, modulesPath
, inputs
, self
, ...
}:
let
  system = config.nixpkgs.system;
  pkgs-self = self.packages.${system};
in
{
  disabledModules = [
    "profiles/all-hardware.nix"
  ];

  disko = {
    memSize = 4096;
    enableConfig = true;
    profile.use = "btrfs";
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
