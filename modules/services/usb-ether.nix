{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.usb-ether;
  gadget = "/sys/kernel/config/usb_gadget/g1";

  bindScript = pkgs.writeShellScript "usb-ether-bind" ''
    set -eu

    G=${gadget}
    UDC="''${1:?missing UDC name}"

    # The UDC may disappear again while Type-C changes roles.
    if [ ! -e "/sys/class/udc/$UDC" ]; then
      exit 0
    fi

    if [ ! -d "$G" ]; then
      echo "USB gadget has not been configured" >&2
      exit 1
    fi

    CURRENT="$(cat "$G/UDC")"
    if [ "$CURRENT" = "$UDC" ]; then
      exit 0
    fi

    if [ -n "$CURRENT" ]; then
      echo "" > "$G/UDC"
    fi

    echo "$UDC" > "$G/UDC"
    [ "$(cat "$G/UDC")" = "$UDC" ]
  '';

  setupScript = pkgs.writeShellScript "usb-ether-setup" ''
    set -eu

    G=${gadget}
    BIND=${bindScript}

    cleanup_gadget() {
      if [ ! -d "$G" ]; then
        return 0
      fi

      echo "" > "$G/UDC" || true
      find "$G" -depth -type l -exec rm -f {} +
      find "$G" -depth -mindepth 1 -type d -exec rmdir {} + 2>/dev/null || true
      rmdir "$G" 2>/dev/null || true
    }

    cleanup_gadget

    mkdir -p "$G"
    cd "$G"

    echo "0x1d6b" > idVendor
    echo "0x0104" > idProduct
    echo "0x0200" > bcdUSB
    echo "0xef" > bDeviceClass
    echo "0x02" > bDeviceSubClass
    echo "0x01" > bDeviceProtocol
    echo "0x3066" > bcdDevice

    # Microsoft OS descriptors bind the RNDIS interface on Windows.
    echo "1" > os_desc/use
    echo "0xcd" > os_desc/b_vendor_code
    echo "MSFT100" > os_desc/qw_sign

    mkdir -p strings/0x409
    echo "1234567890" > strings/0x409/serialnumber
    echo "Rockchip" > strings/0x409/manufacturer
    echo "RK3588 USB Ethernet" > strings/0x409/product

    mkdir -p configs/c.1/strings/0x409
    echo "RNDIS + CDC ECM" > configs/c.1/strings/0x409/configuration
    echo "500" > configs/c.1/MaxPower

    mkdir -p functions/rndis.usb0
    echo "RNDIS" > functions/rndis.usb0/os_desc/interface.rndis/compatible_id
    echo "5162001" > functions/rndis.usb0/os_desc/interface.rndis/sub_compatible_id
    echo "02:00:00:00:00:01" > functions/rndis.usb0/dev_addr
    echo "02:00:00:00:00:02" > functions/rndis.usb0/host_addr

    mkdir -p functions/ecm.usb1
    echo "02:00:00:00:00:03" > functions/ecm.usb1/dev_addr
    echo "02:00:00:00:00:04" > functions/ecm.usb1/host_addr

    ln -s functions/rndis.usb0 configs/c.1
    ln -s functions/ecm.usb1 configs/c.1
    ln -s configs/c.1 os_desc

    # Bind immediately when the port is already in device mode. Otherwise the
    # udev-triggered bind service will run when the UDC appears later.
    for UDC_PATH in /sys/class/udc/*; do
      if [ -e "$UDC_PATH" ]; then
        "$BIND" "$(basename "$UDC_PATH")"
        break
      fi
    done
  '';

  teardownScript = pkgs.writeShellScript "usb-ether-teardown" ''
    set -eu

    G=${gadget}

    if [ -d "$G" ]; then
      echo "" > "$G/UDC" || true
      find "$G" -depth -type l -exec rm -f {} +
      find "$G" -depth -mindepth 1 -type d -exec rmdir {} + 2>/dev/null || true
      rmdir "$G" 2>/dev/null || true
    fi
  '';
in
{
  options.services.usb-ether = {
    enable = lib.mkEnableOption "USB RNDIS and CDC ECM Ethernet gadget";

    ipv4Address = lib.mkOption {
      type = lib.types.str;
      default = "10.0.10.1";
      description = "IPv4 address assigned to the USB Ethernet bridge.";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.kernelModules = [
      "configfs"
      "libcomposite"
    ];

    networking = {
      networkmanager.unmanaged = [
        "usb0"
        "usb1"
        "usb-gadget"
      ];
      useNetworkd = true;
      firewall.trustedInterfaces = [ "usb-gadget" ];
    };

    systemd.network = {
      netdevs."30-usb-gadget".netdevConfig = {
        Kind = "bridge";
        Name = "usb-gadget";
      };

      networks = {
        "40-usb-gadget-members" = {
          matchConfig.Name = "usb0 usb1";
          networkConfig.Bridge = "usb-gadget";
          linkConfig.RequiredForOnline = "no";
        };

        "40-usb-gadget" = {
          matchConfig.Name = "usb-gadget";
          address = [ "${cfg.ipv4Address}/30" ];
          networkConfig = {
            ConfigureWithoutCarrier = true;
            DHCPServer = "yes";
          };
          dhcpServerConfig = {
            PoolSize = 1;
            EmitDNS = "no";
            EmitRouter = "no";
          };
        };
      };
    };

    services.udev.extraRules = ''
      SUBSYSTEM=="udc", ACTION=="add", TAG+="systemd", ENV{SYSTEMD_WANTS}+="usb-ether-bind@%k.service"
    '';

    systemd.services = {
      usb-ether = {
        description = "USB RNDIS and CDC ECM Ethernet gadget";
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

      "usb-ether-bind@" = {
        description = "Bind USB Ethernet gadget to UDC %I";
        after = [ "usb-ether.service" ];
        requires = [ "usb-ether.service" ];

        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${bindScript} %I";
        };
      };
    };
  };
}
