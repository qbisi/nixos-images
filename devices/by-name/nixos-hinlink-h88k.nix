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

  networking.hostName = lib.mkDefault "h88k";

  disko = {
    enableConfig = true;
    bootImage = {
      fileSystem = "btrfs";
      espStart = "16M";
      uboot.enable = true;
      uboot.package = pkgs.ubootHinlinkH88k;
    };
  };

  hardware = {
    firmware = [
      (pkgs.armbian-firmware.override {
        filters = [
          "arm/mali/*"
          "rtl_nic/*"
          "mediatek/*"
          "regulatory.db"
          "hinlink-h88k-240x135-lcd.bin"
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

  services.udev.packages = [
    (pkgs.writeTextFile {
      name = "setting-led-udev-rules";
      destination = "/etc/udev/rules.d/90-setting-led.rules";
      text = ''
        ACTION=="add", SUBSYSTEM=="leds", KERNEL=="blue:net", ATTR{device_name}="wwan0"
        ACTION=="add", SUBSYSTEM=="leds", KERNEL=="blue:net", ATTR{link}="1"
        ACTION=="add", SUBSYSTEM=="leds", KERNEL=="blue:net", ATTR{rx}="1"
        ACTION=="add", SUBSYSTEM=="leds", KERNEL=="blue:net", ATTR{tx}="1"
      '';
    })
  ];

  boot = {
    kernelPackages = pkgs.linuxPackagesFor pkgs.linux_rockchip64_6_18;
    initrd.availableKernelModules = lib.mkIf (
      !config.boot.kernelPackages.kernel.configfile.autoModules
    ) (lib.mkForce [ ]);
    kernelModules = [ "ledtrig-netdev" ];
    kernelParams = [
      "console=tty1"
      "earlycon"
      "net.ifnames=0"
    ];
    loader.grub.enable = true;
  };

}
