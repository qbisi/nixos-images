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
    echo "0x0200" > bcdUSB
    echo "0x02" > bDeviceClass
    echo "0x02" > bDeviceSubClass
    echo "0x00" > bDeviceProtocol
    echo "0x3066" > bcdDevice

    # Windows extensions to force config
    echo "1" > os_desc/use
    echo "0xcd" > os_desc/b_vendor_code
    echo "MSFT100" > os_desc/qw_sign

    mkdir -p strings/0x409
    echo "${cfg.serialNumber}" > strings/0x409/serialnumber
    echo "${cfg.manufacturer}" > strings/0x409/manufacturer
    echo "${cfg.product}" > strings/0x409/product

    # Single RNDIS-only configuration.
    mkdir -p configs/c.1/strings/0x409
    echo "${cfg.configuration}" > configs/c.1/strings/0x409/configuration
    echo "${toString cfg.maxPower}" > configs/c.1/MaxPower

    mkdir -p functions/rndis.usb0
    echo "RNDIS" > functions/rndis.usb0/os_desc/interface.rndis/compatible_id
    echo "5162001" > functions/rndis.usb0/os_desc/interface.rndis/sub_compatible_id
    echo "${cfg.devAddr}" > functions/rndis.usb0/dev_addr
    echo "${cfg.hostAddr}" > functions/rndis.usb0/host_addr
    echo "${toString cfg.qmult}" > functions/rndis.usb0/qmult || true

    # Link only the RNDIS function, per the Windows driver-binding workaround.
    ln -s functions/rndis.usb0 configs/c.1

    # Expose the RNDIS configuration through Microsoft OS descriptors.
    ln -s configs/c.1 os_desc

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
      default = 500;
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
      default = "10.0.10.1";
      description = "IPv4 address assigned to the USB RNDIS interface.";
    };

    prefixLength = lib.mkOption {
      type = lib.types.int;
      default = 30;
      description = "Prefix length assigned to the USB RNDIS interface.";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.kernelModules = [
      "configfs"
      "libcomposite"
    ];

    networking = {
      networkmanager.unmanaged = [ cfg.interface ];
      useNetworkd = true;
      firewall.trustedInterfaces = [ cfg.interface ];
    };

    systemd.network.networks."40-${cfg.interface}" = {
      matchConfig.Name = cfg.interface;
      address = [
        "${cfg.ipv4Address}/${toString cfg.prefixLength}"
      ];
      networkConfig = {
        DHCPServer = "yes";
      };
      dhcpServerConfig = {
        PoolSize = 2;
        EmitDNS = "no";
        EmitRouter = "no";
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
