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
      fileSystem = "btrfs";
      espStart = "16M";
      uboot.enable = true;
      uboot.package = pkgs.ubootJwipcE88a;
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
      name = "rockchip/rk3588-jwipc-e88a.dtb";
      platform = "rockchip";
      dtsFile = ../../dts/mainline/rk3588-jwipc-e88a.dts;
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
    libgpiod
  ];

  boot = {
    kernelPackages = lib.mkDefault (pkgs.linuxPackagesFor pkgs.linux_rockchip64_6_18);
    initrd.allowMissingModules = !config.boot.kernelPackages.kernel.configfile.autoModules;
    kernelParams = [
      "console=tty1"
      "earlycon"
      "net.ifnames=0"
    ];
    consoleLogLevel = 6;
    loader.grub.enable = true;
  };

}
