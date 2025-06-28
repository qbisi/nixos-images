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
  };

  networking.hostName = lib.mkDefault "e88a";

  disko = {
    enableConfig = true;
    bootImage = {
      imageSize = "2G";
      fileSystem = "btrfs";
      espStart = "16M";
      # uboot.enable = true;
      # uboot.package = pkgs.ubootHinlinkH88k;
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
        ];
      })
    ];
    deviceTree = {
      name = "rockchip/rk3588-jea-e88a.dtb";
      platform = "rockchip";
      dtsFile = ../../dts/mainline/rk3588-jea-e88a.dts;
    };
    serial = {
      enable = true;
      unit = 2;
      baudrate = 1500000;
    };
  };

  environment.systemPackages = with pkgs; [
    usbutils
    pciutils
    minicom
  ];

  boot = {
    kernelPackages = pkgs.linuxPackagesFor pkgs.linux_rockchip64_6_15;
    initrd.availableKernelModules = lib.mkForce [ ];
    kernelParams = [
      "console=ttyS2,1500000n8"
      "earlycon"
      "net.ifnames=0"
      "initcall_debug"
    ];
    consoleLogLevel = 6;
    loader.grub.enable = true;
  };

}
