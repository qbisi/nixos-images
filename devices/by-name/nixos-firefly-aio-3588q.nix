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

  networking.hostName = lib.mkDefault "f88q";

  disko = {
    enableConfig = true;
    bootImage = {
      enableESP = false;
      fileSystem = "ext4";
      primaryStart = "16M";
      uboot.enable = true;
      uboot.package = pkgs.buildUBootRk3588 {
        withRecovery = true;
        dtsFile = ../../dts/mainline/rk3588-firefly-aio-3588q.dts;
      };
    };
  };

  hardware = {
    firmware = [
      (pkgs.armbian-firmware.override {
        filters = [
          "arm/mali/*"
          "rtl_nic/*"
          "mediatek/*"
          "ap6275p/*"
          "brcm/*"
          "updates/*"
          "regulatory.db"
        ];
      })
    ];
    deviceTree = {
      name = "rockchip/rk3588-firefly-aio-3588q.dtb";
      platform = "rockchip";
      dtsFile = ../../dts/mainline/rk3588-firefly-aio-3588q.dts;
      overlays = [
        {
          name = "mipi-yx4005";
          dtsFile = ../../dts/mainline/overlays/rk3588-mipi-yx4005.dtso;
        }
      ];
      dtboBuildExtraIncludePaths = lib.mkAfter [ ../../dts/mainline ];
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
    kernelPackages = pkgs.linuxPackagesFor pkgs.linux_rockchip64_6_18;
    initrd.allowMissingModules = !config.boot.kernelPackages.kernel.configfile.autoModules;
    kernelParams = [
      "console=tty1"
      "earlycon"
      "net.ifnames=0"
    ];
    consoleLogLevel = 6;
    loader.timeout = 0;
    loader.grub.enable = false;
    loader.generic-extlinux-compatible.enable = true;
  };

}
