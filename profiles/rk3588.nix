{
  config,
  lib,
  pkgs,
  ...
}:
{
  nixpkgs = {
    system = "aarch64-linux";
  };

  disko = {
    bootImage = {
      primaryStart = lib.mkIf config.disko.bootImage.uboot.enable "16M";
      uboot = {
        enable = lib.mkDefault true;
        imageFile = "u-boot-rockchip.bin";
        seek = 64;
        package = lib.mkDefault (
          pkgs.buildUBootRk3588 {
            dtsFile = config.hardware.deviceTree.dtsFile;
          }
        );
      };
    };
  };

  hardware = {
    enableAllHardware = false;
    wirelessRegulatoryDatabase = true;
    deviceTree.enable = true;
    firmware = [
      pkgs.rockchip-firmware
    ];
    serial = {
      enable = lib.mkDefault true;
      unit = 2;
      baudrate = 1500000;
    };
  };

  boot = {
    kernelPackages = lib.mkDefault (pkgs.linuxPackagesFor pkgs.linux_rockchip64_7_0);
    kernelParams = [
      "net.ifnames=0"
    ];
    initrd.allowMissingModules = !config.boot.kernelPackages.kernel.configfile.autoModules;
  };

  services = {
    usb-rndis.enable = lib.mkDefault true;
  };

  environment = {
    variables = {
      ALSA_CONFIG_UCM2 = "${pkgs.alsa-ucm-conf-rk3588}/share/alsa/ucm2";
    };
    systemPackages = with pkgs; [
      usbutils
      pciutils
      i2c-tools
      libgpiod
      minicom
      ethtool
      vim
      rktop
    ];
  };
}
