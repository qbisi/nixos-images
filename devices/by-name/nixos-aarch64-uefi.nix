{
  config,
  pkgs,
  lib,
  inputs,
  self,
  ...
}:
{
  nixpkgs = {
    system = "aarch64-linux";
    overlays = [
      self.overlays.default
    ];
  };

  disko = {
    enableConfig = true;
    bootImage.fileSystem = "btrfs";
  };

  hardware = {
    serial = {
      enable = true;
    };
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
