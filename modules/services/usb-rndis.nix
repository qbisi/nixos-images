{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.usb-rndis;

  setupScript = pkgs.writeShellScript "usb-rndis-setup" ''
    set -eu

    G=/sys/kernel/config/usb_gadget/g1
    UDC="$(${lib.getExe' pkgs.coreutils "ls"} /sys/class/udc | ${lib.getExe' pkgs.coreutils "head"} -n 1)"
    FIND=${lib.getExe pkgs.findutils}
    RM=${lib.getExe' pkgs.coreutils "rm"}
    RMDIR=${lib.getExe' pkgs.coreutils "rmdir"}

    cleanup_gadget() {
      if [ ! -d "$G" ]; then
        return 0
      fi

      echo "" > "$G/UDC" || true

      "$FIND" "$G" -depth -type l -exec "$RM" -f {} +
      "$FIND" "$G" -depth -mindepth 1 -type d -exec "$RMDIR" {} + 2>/dev/null || true
      "$RMDIR" "$G" 2>/dev/null || true
    }

    cleanup_gadget

    mkdir -p "$G"
    cd "$G"

    echo "${cfg.idVendor}" > idVendor
    echo "${cfg.idProduct}" > idProduct
    echo "${cfg.bcdUSB}" > bcdUSB
    echo "${cfg.bcdDevice}" > bcdDevice

    mkdir -p strings/0x409
    echo "${cfg.serialNumber}" > strings/0x409/serialnumber
    echo "${cfg.manufacturer}" > strings/0x409/manufacturer
    echo "${cfg.product}" > strings/0x409/product

    mkdir -p configs/c.1/strings/0x409
    echo "${cfg.configuration}" > configs/c.1/strings/0x409/configuration
    echo "${toString cfg.maxPower}" > configs/c.1/MaxPower

    mkdir -p functions/rndis.gs0
    echo "${cfg.devAddr}" > functions/rndis.gs0/dev_addr
    echo "${cfg.hostAddr}" > functions/rndis.gs0/host_addr

    echo "${toString cfg.qmult}" > functions/rndis.gs0/qmult || true

    ln -s functions/rndis.gs0 configs/c.1/

    echo "$UDC" > UDC
  '';

  teardownScript = pkgs.writeShellScript "usb-rndis-teardown" ''
    set -eu

    G=/sys/kernel/config/usb_gadget/g1
    FIND=${lib.getExe pkgs.findutils}
    RM=${lib.getExe' pkgs.coreutils "rm"}
    RMDIR=${lib.getExe' pkgs.coreutils "rmdir"}

    if [ -d "$G" ]; then
      echo "" > "$G/UDC" || true
      "$FIND" "$G" -depth -type l -exec "$RM" -f {} +
      "$FIND" "$G" -depth -mindepth 1 -type d -exec "$RMDIR" {} + 2>/dev/null || true
      "$RMDIR" "$G" 2>/dev/null || true
    fi
  '';
in
{
  options.services.usb-rndis = {
    enable = lib.mkEnableOption "USB RNDIS gadget";

    idVendor = lib.mkOption {
      type = lib.types.str;
      default = "0x1d6b";
      description = "USB gadget vendor ID written to configfs.";
    };

    idProduct = lib.mkOption {
      type = lib.types.str;
      default = "0x0104";
      description = "USB gadget product ID written to configfs.";
    };

    bcdUSB = lib.mkOption {
      type = lib.types.str;
      default = "0x0200";
      description = "USB specification version written to configfs.";
    };

    bcdDevice = lib.mkOption {
      type = lib.types.str;
      default = "0x0100";
      description = "Device release number written to configfs.";
    };

    serialNumber = lib.mkOption {
      type = lib.types.str;
      default = "1234567890";
      description = "USB gadget serial number.";
    };

    manufacturer = lib.mkOption {
      type = lib.types.str;
      default = "Rockchip";
      description = "USB gadget manufacturer string.";
    };

    product = lib.mkOption {
      type = lib.types.str;
      default = "RK3588 RNDIS";
      description = "USB gadget product string.";
    };

    configuration = lib.mkOption {
      type = lib.types.str;
      default = "RNDIS";
      description = "USB gadget configuration string.";
    };

    maxPower = lib.mkOption {
      type = lib.types.int;
      default = 120;
      description = "USB gadget MaxPower value for the RNDIS configuration.";
    };

    devAddr = lib.mkOption {
      type = lib.types.str;
      default = "02:00:00:00:00:01";
      description = "MAC address exposed by the USB device side.";
    };

    hostAddr = lib.mkOption {
      type = lib.types.str;
      default = "02:00:00:00:00:02";
      description = "MAC address exposed to the USB host side.";
    };

    qmult = lib.mkOption {
      type = lib.types.int;
      default = 1;
      description = "RNDIS queue multiplier written when supported.";
    };

    interface = lib.mkOption {
      type = lib.types.str;
      default = "usb0";
      description = "Name of the USB RNDIS network interface.";
    };

    ipv4Address = lib.mkOption {
      type = lib.types.str;
      default = "192.168.42.1";
      description = "IPv4 address assigned to the USB RNDIS interface.";
    };

    prefixLength = lib.mkOption {
      type = lib.types.int;
      default = 24;
      description = "Prefix length assigned to the USB RNDIS interface.";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.kernelModules = [
      "configfs"
      "libcomposite"
    ];

    networking.networkmanager.unmanaged = [ cfg.interface ];

    systemd.network.networks."40-${cfg.interface}" = {
      matchConfig.Name = cfg.interface;
      address = [
        "${cfg.ipv4Address}/${toString cfg.prefixLength}"
      ];
      networkConfig = {
        DHCPServer = "yes";
      };
      dhcpServerConfig = {
        EmitDNS = "yes";
        DNS = cfg.ipv4Address;
      };
    };

    systemd.services.usb-rndis = {
      description = "USB RNDIS gadget";
      wantedBy = [ "multi-user.target" ];
      after = [ "sys-kernel-config.mount" ];
      requires = [ "sys-kernel-config.mount" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = setupScript;
        ExecStop = teardownScript;
      };
    };
  };
}
