{
  config,
  pkgs,
  lib,
  self,
  ...
}:
{
  nixpkgs = {
    system = "x86_64-linux";
    overlays = [
      self.overlays.default
    ];
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
