{
  config,
  lib,
  pkgs,
  utils,
  ...
}:
let
  cfg = config.boot.espRelocation;
in
{
  options = {
    boot.espRelocation = {
      enable = lib.mkEnableOption "esp part relocation in gpt disk" // {
        default = config.disko.bootImage.enableESP;
      };
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services = {
      relocate-esp = {
        description = "Move EFI system partition to the end of the disk";
        wantedBy = [ "multi-user.target" ];
        after = [
          "-.mount"
          "systemd-udev-settle.service"
        ];
        before = [
          "growpart.service"
          "shutdown.target"
        ];
        conflicts = [ "shutdown.target" ];
        unitConfig.DefaultDependencies = false;
        wants = [ "systemd-udev-settle.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        path = with pkgs; [
          gptfdisk
        ];
        script =
          let
            espPartition = config.disko.devices.disk.main.content.partitions.ESP;
          in
          ''
            set -euo pipefail

            espDevice="${espPartition.device}"
            espDevice="$(readlink -f "$espDevice")"
            parentDevice="$espDevice"
            while [ "''${parentDevice%[0-9]}" != "''${parentDevice}" ]; do
              parentDevice="''${parentDevice%[0-9]}";
            done
            espPartNum="''${espDevice#"''${parentDevice}"}"
            if [ "''${parentDevice%[0-9]p}" != "''${parentDevice}" ] && [ -b "''${parentDevice%p}" ]; then
              parentDevice="''${parentDevice%p}"
            fi
            espBackup="/tmp/relocate-esp.img"

            dd if="$espDevice" of="$espBackup" bs=4M conv=fsync status=none

            if findmnt --mountpoint ${espPartition.content.mountpoint} >/dev/null 2>&1; then
              umount ${espPartition.content.mountpoint}
            fi

            sgdisk --move-second-header "$parentDevice"
            sgdisk --delete="$espPartNum" "$parentDevice"
            sgdisk \
              --align-end \
              --new="$espPartNum:${espPartition.start}:${espPartition.end}" \
              --change-name="$espPartNum:${espPartition.label}" \
              --typecode="$espPartNum:EF00" \
              --attributes="$espPartNum:=:0" \
              "$parentDevice"

            dd if="$espBackup" of="$espDevice" bs=4M conv=fsync status=none
            mount -a
          '';
      };
    };
  };
}
