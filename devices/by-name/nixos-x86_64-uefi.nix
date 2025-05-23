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
    system = "x86_64-linux";
  };

  disko = {
    enableConfig = true;
    bootImage.fileSystem = "btrfs";
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
