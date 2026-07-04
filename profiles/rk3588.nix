{
  config,
  lib,
  pkgs,
  ...
}:
{
  nixpkgs = {
    system = "aarch64-linux";
  };

  disko = {
    bootImage = {
      primaryStart = lib.mkIf config.disko.bootImage.uboot.enable "16M";
      uboot = {
        enable = lib.mkDefault true;
        imageFile = "u-boot-rockchip.bin";
        seek = 64;
        package = lib.mkDefault (
          pkgs.buildUBootRk3588 {
            dtsFile = config.hardware.deviceTree.dtsFile;
          }
        );
      };
    };
  };

  hardware = {
    enableAllHardware = false;
    wirelessRegulatoryDatabase = true;
    deviceTree = {
      enable = true;
      overlays = [
        {
          name = "gpu-opp-table";
          dtsFile = ../dts/mainline/overlays/rk3588-gpu-opp-voltage-fix.dtso;
        }
      ];
    };
    firmware = [
      pkgs.rockchip-firmware
    ];
    serial = {
      enable = lib.mkDefault true;
      unit = 2;
      baudrate = 1500000;
    };
  };

  boot = {
    kernelPackages = lib.mkDefault (pkgs.linuxPackagesFor pkgs.linux_rockchip64_7_1);
    kernelParams = [
      "net.ifnames=0"
    ];
    initrd.allowMissingModules = !config.boot.kernelPackages.kernel.configfile.autoModules;
  };

  services = {
    usb-rndis.enable = lib.mkDefault true;

    pipewire.wireplumber.extraConfig = {
      rk3588-sound = {
        "monitor.alsa.rules" = [
          {
            matches = [
              {
                "device.name" = "alsa_card.platform-hdmi0-sound";
              }
            ];
            actions = {
              update-props = {
                "device.description" = "HDMI 0";
                "device.form-factor" = "hdmi";
                "device.icon-name" = "video-display";
              };
            };
          }
          {
            matches = [
              {
                "device.name" = "alsa_card.platform-hdmi1-sound";
              }
            ];
            actions = {
              update-props = {
                "device.description" = "HDMI 1";
                "device.form-factor" = "hdmi";
                "device.icon-name" = "video-display";
              };
            };
          }
          {
            matches = [
              {
                "device.name" = "alsa_card.platform-analog-sound";
              }
            ];
            actions = {
              update-props = {
                "device.description" = "Cuffie / Line Out";
              };
            };
          }
          {
            matches = [
              {
                "node.name" = "alsa_output.platform-hdmi0-sound.stereo-fallback";
              }
            ];
            actions = {
              update-props = {
                "node.description" = "HDMI 0 (LG TV)";
                "node.nick" = "HDMI 0";
              };
            };
          }
        ];
      };
    };
  };

  environment = {
    variables = {
      ALSA_CONFIG_UCM2 = "${pkgs.alsa-ucm-conf-rk3588}/share/alsa/ucm2";
    };
    systemPackages = with pkgs; [
      usbutils
      pciutils
      i2c-tools
      libgpiod
      minicom
      ethtool
      vim
      rktop
    ];
  };
}
