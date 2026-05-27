{
  config,
  pkgs,
  lib,
  self,
  inputs,
  inputs',
  ...
}:
{
  deployment = {
    targetHost = "10.0.10.1";
    targetUser = "root";
    buildOnTarget = false;
  };

  imports = [
    "${self}/devices/by-name/nixos-radxa-rock-5t.nix"
    "${self}/modules/config/passless.nix"
  ];

  boot = {
    extraModulePackages = [
      (pkgs.panel-simple-dsi.override { linux = config.boot.kernelPackages.kernel; })
      (pkgs.sgm37604-backlight.override { linux = config.boot.kernelPackages.kernel; })
      (pkgs.sec-ts.override { linux = config.boot.kernelPackages.kernel; })
      (pkgs.tcpci-husb311.override { linux = config.boot.kernelPackages.kernel; })
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

  networking = {
    firewall.enable = false;
    nftables.enable = true;
  };

  services = {
    usb-rndis.enable = true;
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

  environment.systemPackages = with pkgs; [
    iperf3
  ];

  documentation.enable = false;

  nix = {
    settings = {
      substituters = lib.mkForce [ ];
      experimental-features = [
        "nix-command"
        "flakes"
      ];
    };
  };
}
