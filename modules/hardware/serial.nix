{ config, lib, ... }:
with lib;
let
  cfg = config.hardware.serial;
in
{
  options = {
    hardware.serial = {
      enable = mkEnableOption "enable serial output";

      unit = mkOption {
        default = 0;
        example = 2;
        type = types.int;
      };

      baudrate = mkOption {
        default = 115200;
        example = 1500000;
        type = types.int;
      };

      word = mkOption {
        default = 8;
        type = types.int;
      };

      parity = mkOption {
        default = "no";
        type = types.enum [
          "no"
          "odd"
          "even"
        ];
      };

      stop = mkOption {
        default = 1;
        type = types.int;
      };
    };
  };

  config = mkMerge [
    {
      boot.loader = mkDefault {
        efi.efiSysMountPoint = "/boot/efi";
        grub = {
          device = "nodev";
          efiSupport = true;
          efiInstallAsRemovable = true;
        };
      };
    }

    (mkIf cfg.enable {
      boot.loader.grub.extraConfig = ''
        serial --unit=${toString cfg.unit} --speed=${toString cfg.baudrate} --word=${toString cfg.word} --parity=${cfg.parity} --stop=${toString cfg.stop}
        terminal_input --append serial
        terminal_output --append serial
      '';

      boot.kernelParams = (mkBefore [ "console=ttyS${toString cfg.unit},${toString cfg.baudrate}" ]);
    })
  ];
}
