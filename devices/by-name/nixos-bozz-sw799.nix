{
  config,
  pkgs,
  lib,
  inputs,
  self,
  ...
}:
let
  system = "aarch64-linux";
in
{
  nixpkgs = {
    system = "aarch64-linux";
    overlays = [
      inputs.nixos-images.overlays.default
    ];
    config = {
      allowUnfreePredicate =
        pkg:
        builtins.elem (pkgs.lib.getName pkg) [
          "arm-trusted-firmware-rk3399"
        ];
    };
  };

  networking.hostName = lib.mkDefault "sw799";

  disko = {
    enableConfig = true;
    bootImage = {
      fileSystem = "btrfs";
      espStart = "16M";
      uboot.enable = true;
      uboot.package = pkgs.ubootBozzSW799;
    };
  };

  hardware = {
    firmware = [ pkgs.brcmfmac-firmware ];
    serial = {
      enable = true;
      unit = 2;
      baudrate = 1500000;
    };
  };

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    kernelParams = [
      "net.ifnames=0"
      "console=tty1"
      "earlycon"
    ];
    loader.grub.enable = true;
  };

}
