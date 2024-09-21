{ config
, pkgs
, lib
, modulesPath
, inputs
, self
, system
, ...
}:
let
  pkgs-self = self.packages.${system};
in
{
  networking.hostName = "hinlink-h88k";

  disko = {
    memSize = 4096;
    profile.extraPostVM =
      let
        diskoCfg = config.disko;
        imageName = "${diskoCfg.devices.disk.main.name}.${diskoCfg.imageBuilder.imageFormat}";
      in
      ''
        ${pkgs.coreutils}/bin/dd of=$out/${imageName} if=${pkgs-self.ubootHinlinkH88k}/u-boot-rockchip.bin bs=4K seek=8 conv=notrunc
      '';
    enableConfig = true;
    profile.use = "btrfs";
    profile.espStart = lib.mkIf (builtins.elem config.disko.profile.partLabel [ "mmc" "sd" ]) "16M";
  };

  hardware = {
    firmware = [ pkgs-self.mali-panthor-g610-firmware ];
    deviceTree = {
      name = "rockchip/rk3588-hinlink-h88k.dtb";
      overlays = [
        { name = "h88k-enable-hdmiphy"; dtsFile = "${self}/dts/overlay/h88k-enable-hdmiphy.dts"; }
        { name = "h88k-enable-rs232-rs485"; dtsFile = "${self}/dts/overlay/h88k-enable-rs232-rs485.dts"; }
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
    initrd.availableKernelModules = lib.mkForce (lib.optional (config.disko.profile.partLabel == "usb") "uas");
    kernelParams = [
      "net.ifnames=0"
      "console=tty1"
      "earlycon"
    ];
    loader.grub.enable = true;
  };

}
