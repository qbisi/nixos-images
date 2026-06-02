{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ../profiles/rk3588.nix
    ../profiles/btrfs.nix
  ];

  networking.hostName = lib.mkDefault "h88k";

  hardware = {
    deviceTree = {
      name = "rockchip/rk3588-hinlink-h88k.dtb";
      platform = "rockchip";
      dtsFile = ../../dts/mainline/rk3588-hinlink-h88k.dts;
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
    kernelModules = [ "ledtrig-netdev" ];
  };
}
