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

  networking.hostName = lib.mkDefault "h88k";

  disko = {
    enableConfig = true;
    bootImage = {
      imageSize = "2G";
      fileSystem = "btrfs";
      espStart = "16M";
      uboot.enable = true;
      uboot.package = pkgs.ubootHinlinkH88k;
    };
  };

  hardware = {
    firmware = [
      (pkgs.armbian-firmware.override {
        filters = [
          "arm/mali/*"
          "rtl_nic/*"
          "mediatek/*"
          "regulatory.db"
          "hinlink-h88k-240x135-lcd.bin"
        ];
      })
    ];
    deviceTree = {
      name = "rockchip/rk3588-hinlink-h88k.dtb";
      platform = "rockchip";
      dtsFile = ../../dts/mainline/rk3588-hinlink-h88k.dts;
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
      "console=tty1"
      "earlycon"
      "net.ifnames=0"
    ];
    loader.grub.enable = true;
  };

}
