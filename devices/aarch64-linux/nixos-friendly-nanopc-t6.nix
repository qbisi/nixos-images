{ config
, pkgs
, pkgs-self
, lib
, modulesPath
, inputs
, self
, ...
}:
{
  nixpkgs.system = "aarch64-linux";

  networking.hostName = lib.mkDefault "nanopc-t6";

  disko = {
    memSize = 4096;
    enableConfig = true;
    profile = {
      use = "btrfs";
      espStart = "16M";
      uboot.enable = true;
      uboot.package = pkgs-self.ubootNanoPCT6;
    };
  };

  hardware = {
    firmware = [ pkgs-self.mali_panthor_g610-firmware pkgs.linux-firmware ];
    deviceTree = {
      name = "rockchip/rk3588-nanopc-t6.dtb";
    };
    serial = {
      enable = true;
      unit = 2;
      baudrate = 1500000;
    };
  };

  boot = {
    kernelPackages = pkgs.linuxPackagesFor pkgs-self.linux_rkbsp_joshua;
    initrd.availableKernelModules = lib.mkForce [];
    kernelParams = [
      "net.ifnames=0"
      "console=tty1"
      "earlycon"
    ];
    loader.grub.enable = true;
  };

}
