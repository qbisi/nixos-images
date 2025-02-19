{
  config,
  pkgs,
  pkgs-self,
  lib,
  modulesPath,
  inputs,
  self,
  ...
}:
{
  nixpkgs.system = "aarch64-linux";

  networking.hostName = lib.mkDefault "opi5";

  disko = {
    memSize = 4096;
    enableConfig = true;
    profile = {
      use = "btrfs";
      espStart = "16M";
      uboot.enable = true;
      uboot.package = pkgs-self.ubootOrangePi5;
    };
  };

  hardware = {
    firmware = [
      pkgs-self.armbian-firmware
    ];
    deviceTree = {
      name = "rockchip/rk3588s-orangepi-5.dtb";
    };
    serial = {
      enable = true;
      unit = 2;
      baudrate = 1500000;
    };
  };

  boot = {
    kernelPackages = pkgs.linuxPackagesFor pkgs-self.linux_rockchip64_6_13;
    initrd.availableKernelModules = lib.mkForce [ ];
    kernelParams = [
      "net.ifnames=0"
      "console=tty1"
      "earlycon"
    ];
    loader.grub.enable = true;
  };

}
