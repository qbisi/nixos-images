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
    config = {
      allowUnfreePredicate =
        pkg:
        builtins.elem (pkgs.lib.getName pkg) [
          "arm-trusted-firmware-rk3399"
        ];
    };
  };

  networking.hostName = lib.mkDefault "jd4";

  disko = {
    enableConfig = true;
    bootImage = {
      fileSystem = "ext4";
      espStart = "16M";
      uboot.enable = true;
      uboot.package = pkgs.ubootFirefly3399jd4;
    };
  };

  hardware = {
    deviceTree = {
      name = "rockchip/rk3399-firefly-core-3399-jd4.dtb";
      platform = "rockchip";
      dtsFile = ../../dts/mainline/rk3399-firefly-core-3399-jd4.dts;
    };
    serial = {
      enable = true;
      unit = 2;
      baudrate = 1500000;
    };
  };

  boot = {
    kernelPackages = pkgs.linuxPackagesFor pkgs.linux_rockchip64_6_18;
    initrd.allowMissingModules = !config.boot.kernelPackages.kernel.configfile.autoModules;
    kernelParams = [
      "net.ifnames=0"
      "console=tty1"
      "earlycon"
    ];
    loader.grub.enable = false;
    loader.generic-extlinux-compatible.enable = true;
  };

}
