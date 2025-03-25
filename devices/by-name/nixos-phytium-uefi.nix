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
      inputs.nixos-images.overlays.default
    ];
  };

  disko = {
    enableConfig = true;
    profile.fileSystem = "btrfs";
  };

  hardware = {
    serial.enable = true;
  };

  boot = {
    kernelPackages = pkgs.linuxPackagesFor pkgs.linux_phytium_6_6;
    kernelParams = [
      "net.ifnames=0"
      "console=tty1"
      "earlycon"
    ];
    loader.grub.enable = true;
  };

}
