# This module automatically grows the root partition.
# This allows an instance to be created with a bigger root filesystem
# than provided by the machine image.

{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

{

  disabledModules = [ "system/boot/grow-partition.nix" ];

  options = {
    boot.growPartition = {
      enable = mkOption {
        default = true;
        type = types.bool;
        description = ''
          growing the root partition on boot
        '';
      };
      mountPoint = mkOption {
        default = "/";
        example = "/nix";
        type = types.str;
        description = ''
          This is the main partition mount point.

          Used when building a stateless image.
        '';
      };
    };
  };

  config =
    let
      cfg = config.boot.growPartition;
      isBtrfs = config.fileSystems.${cfg.mountPoint}.fsType == "btrfs";
      device = config.fileSystems.${cfg.mountPoint}.device;
    in
    mkIf cfg.enable {
      assertions = [
        {
          assertion = !config.boot.initrd.systemd.repart.enable && !config.systemd.repart.enable;
          message = "systemd-repart already grows the root partition and thus you should not use boot.growPartition";
        }
      ];
      systemd.services.growpart = {
        enable = true;
        wantedBy = [ "-.mount" ];
        after = [ "-.mount" ];
        before = [
          "systemd-growfs-root.service"
          "shutdown.target"
          "mkswap-.service"
        ];
        conflicts = [ "shutdown.target" ];
        unitConfig.DefaultDependencies = false;
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          TimeoutSec = "infinity";
          # growpart returns 1 if the partition is already grown
          SuccessExitStatus = "0 1";
        };
        path =
          with pkgs;
          [
            cloud-utils.guest
          ]
          ++ optional isBtrfs btrfs-progs;
        script =
          ''
            device="${device}"
            device="$(readlink -f "$device")"
            parentDevice="$device"
            while [ "''${parentDevice%[0-9]}" != "''${parentDevice}" ]; do
              parentDevice="''${parentDevice%[0-9]}";
            done
            partNum="''${device#''${parentDevice}}"
            if [ "''${parentDevice%[0-9]p}" != "''${parentDevice}" ] && [ -b "''${parentDevice%p}" ]; then
              parentDevice="''${parentDevice%p}"
            fi
            growpart "$parentDevice" "$partNum"
          ''
          + optionalString isBtrfs ''
            btrfs filesystem resize max ${cfg.mountPoint}
          '';
      };
    };
}
