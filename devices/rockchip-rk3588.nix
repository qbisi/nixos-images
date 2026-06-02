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
      primaryStart = "16M";
      uboot = {
        enable = true;
        package = lib.mkDefault (
          pkgs.buildUBootRk3588 {
            withNvme = true;
            dtsFile = config.hardware.deviceTree.dtsFile;
          }
        );
      };
    };
  };

  hardware = {
    firmware = [
      pkgs.linux-firmware
    ];
    serial = {
      enable = true;
      unit = 2;
      baudrate = 1500000;
    };
  };

  boot = {
    kernelPackages = lib.mkDefault (pkgs.linuxPackagesFor pkgs.linux_rockchip64_6_18);
    initrd.allowMissingModules = !config.boot.kernelPackages.kernel.configfile.autoModules;
  };

  services = {
    usb-rndis.enable = true;
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
    ];
  };
}
