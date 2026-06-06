{
  config,
  pkgs,
  lib,
  self,
  ...
}:
{
  imports = [
    ../../devices/by-name/nixos-radxa-rock-5t.nix
  ];

  networking.hostName = "r5t-mobile";

  boot = {
    extraModulePackages = [
      (pkgs.panel-simple-dsi.override { linux = config.boot.kernelPackages.kernel; })
      (pkgs.sgm37604-backlight.override { linux = config.boot.kernelPackages.kernel; })
      (pkgs.sec-ts.override { linux = config.boot.kernelPackages.kernel; })
    ];
  };

  hardware = {
    deviceTree = {
      dtboBuildExtraIncludePaths = lib.mkAfter [ ../../dts/mainline ];
      overlays = [
        {
          name = "mipi-sgm-6fhd";
          dtsFile = ../../dts/mainline/overlays/rock-5t-radxa-display-6fhd.dtso;
        }
      ];
    };
    graphics.enable = true;
  };

  services = {
    udev.extraRules = ''
      # Hide HDMI CEC/RC input devices from libinput. They expose REL_X/REL_Y
      # and look pointer-capable, but this image only needs the panel touch input.
      SUBSYSTEM=="input", KERNEL=="event*", ATTRS{name}=="snps-hdmirx", ENV{LIBINPUT_IGNORE_DEVICE}="1"
      SUBSYSTEM=="input", KERNEL=="event*", ATTRS{name}=="fde80000.hdmi", ENV{LIBINPUT_IGNORE_DEVICE}="1"
      SUBSYSTEM=="input", KERNEL=="event*", ATTRS{name}=="fdea0000.hdmi", ENV{LIBINPUT_IGNORE_DEVICE}="1"
    '';
    cage = {
      enable = true;
      program = "${pkgs.configuration}/bin/configuration";
      user = "root";
    };
  };
}
