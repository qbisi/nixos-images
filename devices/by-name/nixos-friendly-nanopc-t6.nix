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

  networking.hostName = lib.mkDefault "nanopc-t6";

  disko = {
    enableConfig = true;
    bootImage = {
      fileSystem = "btrfs";
      espStart = "16M";
      uboot.enable = true;
      uboot.package = pkgs.ubootNanoPCT6;
    };
  };

  hardware = {
    firmware = [
      pkgs.armbian-firmware
    ];
    deviceTree = {
      name = "rockchip/rk3588-nanopc-t6.dtb";
    };
    serial = {
      enable = true;
      unit = 2;
      baudrate = 1500000;
    };
  };

  boot = {
    kernelPackages = pkgs.linuxPackagesFor pkgs.linux_rockchip64_6_14;
    initrd.availableKernelModules = lib.mkForce [ ];
    kernelParams = [
      "net.ifnames=0"
      "console=tty1"
      "earlycon"
    ];
    loader.grub.enable = true;
  };

}
