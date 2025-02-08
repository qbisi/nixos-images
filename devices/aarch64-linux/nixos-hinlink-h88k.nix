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
    ];
    loader.grub.enable = true;
  };

  # keep kernel source for compiling out-of-tree devicetree source
  system.extraDependencies = [ (lib.getDev config.boot.kernelPackages.kernel) ];

  # map predictable iface
  services.udev.extraRules = ''
    SUBSYSTEM=="net", ACTION=="add", ENV{ID_PATH}=="platform-fe1b0000.ethernet", NAME="eth0"
    SUBSYSTEM=="net", ACTION=="add", ENV{ID_PATH}=="platform-a40c00000.pcie-pci-0003:31:00.0", NAME="eth1"
    SUBSYSTEM=="net", ACTION=="add", ENV{ID_PATH}=="platform-a41000000.pcie-pci-0004:41:00.0", NAME="eth2"
    SUBSYSTEM=="net", ACTION=="add", DEVPATH=="/devices/platform/fc400000.usb/xhci-hcd.6.auto/usb8/8-1/8-1.1/8-1.1:1.8/net/wwan0", NAME="wwan0"
  '';

}
