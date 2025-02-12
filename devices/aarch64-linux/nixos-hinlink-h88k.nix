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

  networking.hostName = lib.mkDefault "h88k";

  disko = {
    memSize = 4096;
    enableConfig = true;
    profile = {
      imageSize = "2G";
      use = "btrfs";
      espStart = "16M";
      uboot.enable = true;
      uboot.package = pkgs-self.ubootHinlinkH88k;
    };
  };

  hardware = {
    firmware = [
      (pkgs-self.armbian-firmware.override {
        filters = [
          "arm/mali/*"
          "rtl_nic/*"
          "mediatek/*"
        ];
      })
    ];
    deviceTree = {
      name = "rockchip/rk3588-hinlink-h88k.dtb";
      platform = "rockchip";
      dtsFile = ../../dts/mainline/rk3588-hinlink-h88k.dts;
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
      "console=tty1"
      "earlycon"
      "net.ifnames=0"
    ];
    loader.grub.enable = true;
  };

  # keep kernel source for compiling out-of-tree devicetree source
  # system.extraDependencies = [ (lib.getDev config.boot.kernelPackages.kernel) ];

}
