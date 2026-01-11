{
  config,
  pkgs,
  lib,
  ...
}:
{
  nixpkgs.system = "aarch64-linux";

  networking.hostName = lib.mkDefault "cm3588-nas";

  disko = {
    enableConfig = true;
    bootImage = {
      fileSystem = "btrfs";
      espStart = "16M";

      uboot = {
        enable = true;
        package = pkgs.ubootCM3588NAS;
      };
    };
  };

  hardware = {
    firmware = [
      pkgs.armbian-firmware
    ];

    deviceTree = {
      name = "rockchip/rk3588-friendlyelec-cm3588-nas.dtb";
    };

    serial = {
      enable = true;
      unit = 2;
      baudrate = 1500000;
    };
  };

  boot = {
    kernelPackages = lib.mkDefault (pkgs.linuxPackagesFor pkgs.linux_rockchip64_6_18);

    initrd.allowMissingModules = !config.boot.kernelPackages.kernel.configfile.autoModules;

    kernelParams = [
      "net.ifnames=0"
      "console=tty1"
      "earlycon"
    ];

    loader.grub.enable = true;
  };
}
