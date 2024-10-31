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

  networking.hostName = lib.mkDefault "hinlink-h88k";

  disko = {
    memSize = 4096;
    enableConfig = true;
    profile = {
      use = "btrfs";
      espStart = "16M";
      uboot.enable = true;
      uboot.package = pkgs-self.ubootHinlinkH88k;
    };
  };

  hardware = {
    firmware = [
      pkgs-self.mali_panthor_g610-firmware
      pkgs.linux-firmware
    ];
    deviceTree = {
      name = "rockchip/rk3588-hinlink-h88k.dtb";
      overlays = [
        {
          name = "h88k-enable-hdmiphy";
          dtsFile = ../../dts/overlay/h88k-enable-hdmiphy.dts;
        }
        {
          name = "h88k-enable-rs232-rs485";
          dtsFile = ../../dts/overlay/h88k-enable-rs232-rs485.dts;
        }
      ];
    };
    serial = {
      enable = true;
      unit = 2;
      baudrate = 1500000;
    };
  };

  boot = {
    kernelPackages = pkgs.linuxPackagesFor pkgs-self.linux_rkbsp_joshua;
    initrd.availableKernelModules = lib.mkForce [ ];
    kernelParams = [
      "net.ifnames=0"
      "console=tty1"
      "earlycon"
    ];
    loader.grub.enable = true;
  };

}
