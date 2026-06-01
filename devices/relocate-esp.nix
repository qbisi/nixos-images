{
  config,
  lib,
  pkgs,
  utils,
  ...
}:
let
  cfg = config.boot.espRelocation;
  espMountPoint = config.boot.loader.efi.efiSysMountPoint;
  espMountUnit = "${utils.escapeSystemdPath espMountPoint}.mount";
in
{
  options = {
    boot.espRelocation = {
      enable = lib.mkEnableOption "esp part relocation in gpt disk" // {
        default = true;
      };
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services = {
      relocate-esp = {
        description = "Move EFI system partition to the end of the disk";
        requiredBy = [ espMountUnit ];
        after = [
          "-.mount"
          "systemd-udev-settle.service"
        ];
        before = [
          espMountUnit
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
          coreutils
          gawk
          gptfdisk
          gnused
          util-linux
        ];
        script = ''
          set -euo pipefail

          espDeviceSpec="${config.fileSystems.${espMountPoint}.device}"
          espDevice="$(readlink -f "$espDeviceSpec")"
          parentDevice="$espDevice"
          while [ "''${parentDevice%[0-9]}" != "''${parentDevice}" ]; do
            parentDevice="''${parentDevice%[0-9]}";
          done
          espPartNum="''${espDevice#"''${parentDevice}"}"
          if [ "''${parentDevice%[0-9]p}" != "''${parentDevice}" ] && [ -b "''${parentDevice%p}" ]; then
            parentDevice="''${parentDevice%p}"
          fi
          espBackup="/tmp/relocate-esp.img"

          espPartitionInfo="$(sgdisk --info="$espPartNum" "$parentDevice")"
          espPartitionLabel="$(printf '%s\n' "$espPartitionInfo" | sed -n "s/^Partition name: '\(.*\)'$/\1/p")"
          espTypeCode="$(printf '%s\n' "$espPartitionInfo" | awk '/^Partition GUID code:/ { print $4 }')"
          espAttributes="$(printf '%s\n' "$espPartitionInfo" | awk '/^Attribute flags:/ { print $3 }')"

          dd if="$espDevice" of="$espBackup" bs=4M conv=fsync status=none
          sectorSize="$(blockdev --getss "$parentDevice")"
          espSizeBytes="$(stat --printf=%s "$espBackup")"
          espSize="$(((espSizeBytes + sectorSize - 1) / sectorSize))"

          sgdisk --move-second-header "$parentDevice"
          sgdisk --delete="$espPartNum" "$parentDevice"
          sgdisk \
            --align-end \
            --new="$espPartNum:-$espSize:+$espSize" \
            --change-name="$espPartNum:$espPartitionLabel" \
            --typecode="$espPartNum:$espTypeCode" \
            --attributes="$espPartNum:=:$espAttributes" \
            "$parentDevice"

          partx --update --nr "$espPartNum" "$parentDevice"
          udevadm settle --timeout=30
          espDevice="$(readlink -f "$espDeviceSpec")"

          dd if="$espBackup" of="$espDevice" bs=4M conv=fsync status=none
        '';
      };
    };
  };
}
