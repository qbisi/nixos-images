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

  networking.hostName = lib.mkDefault "v1a";

  disko = {
    enableConfig = true;
    bootImage = {
      # enableESP = false;
      fileSystem = "ext4";
      primaryStart = "16M";
      uboot.enable = true;
      uboot.package = pkgs.buildUBootRk3588 {
        withRecovery = true;
        dtsFile = ../../dts/mainline/rk3588-ido-evb3588-v1a.dts;
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
      name = "rockchip/rk3588-ido-evb3588-v1a.dtb";
      platform = "rockchip";
      dtsFile = ../../dts/mainline/rk3588-ido-evb3588-v1a.dts;
    };
    serial = {
      enable = true;
      unit = 2;
      baudrate = 1500000;
    };
  };

  services = {
    usb-rndis.enable = true;
  };

  environment = {
    variables = {
      MESA_GLSL_VERSION_OVERRIDE = 330;
      ALSA_CONFIG_UCM2 = "${pkgs.alsa-ucm-conf-rk3588}/share/alsa/ucm2";
    };
    systemPackages = with pkgs; [
      usbutils
      pciutils
      i2c-tools
      libgpiod
      alsa-utils
      v4l-utils
      minicom
      evtest
      libinput
      ethtool
    ];
  };

  boot = {
    kernelPackages = pkgs.linuxPackagesFor pkgs.linux_rockchip64_7_0;
    initrd.allowMissingModules = !config.boot.kernelPackages.kernel.configfile.autoModules;
    kernelParams = [
      "console=tty1"
      "earlycon"
      "net.ifnames=0"
    ];
    consoleLogLevel = 6;
    loader.timeout = 0;
    # mipi output is for now broken with extlinux
    # loader.grub.enable = false;
    # loader.generic-extlinux-compatible.enable = true;
  };

}
