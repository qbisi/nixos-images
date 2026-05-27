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

  networking.hostName = lib.mkDefault "r5t";

  disko = {
    enableConfig = true;
    bootImage = {
      enableESP = true;
      partLabel = "nvme";
      fileSystem = "ext4";
      primaryStart = "1M";
      uboot.enable = false;
      uboot.package = pkgs.buildUBootRk3588 {
        withSpi = true;
        withNvme = true;
        dtsFile = config.hardware.deviceTree.dtsFile;
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
      name = "rockchip/rk3588-rock-5t.dtb";
      platform = "rockchip";
      dtsFile = ../../dts/mainline/rockchip/rk3588-rock-5t.dts;
    };
    serial = {
      enable = true;
      unit = 2;
      baudrate = 1500000;
    };
  };

  environment = {
    sessionVariables = {
      MESA_GLSL_VERSION_OVERRIDE = 330;
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
    loader.grub.enable = config.disko.bootImage.enableESP;
    loader.generic-extlinux-compatible.enable = !config.disko.bootImage.enableESP;
  };

}
