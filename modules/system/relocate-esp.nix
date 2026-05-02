{
  config,
  lib,
  pkgs,
  utils,
  ...
}:

let
  growPartition = config.boot.growPartition;
  growPartitionEnable =
    if builtins.isAttrs growPartition then growPartition.enable else growPartition;
  growPartitionMountPoint = if builtins.isAttrs growPartition then growPartition.mountPoint else "/";
  diskoCfg = config.disko.bootImage;
  espPartition = config.disko.devices.disk.main.content.partitions.ESP;
  espContent = espPartition.content;
  enableESPRelocation =
    growPartitionEnable
    && config.disko.enableConfig
    && diskoCfg.fileSystem != null
    && diskoCfg.enableESP;
  espHasFileSystem =
    espContent != null
    && espContent.type == "filesystem"
    && espContent.format == "vfat"
    && espContent.mountpoint != null;
  espMountOptions = espContent.mountOptions or [ ];
  espMountOptionArgs = lib.concatMapStringsSep " " (
    opt: "-o ${lib.escapeShellArg opt}"
  ) espMountOptions;
in

{
  config = lib.mkIf growPartitionEnable {
    assertions = [
      {
        assertion = !enableESPRelocation || espHasFileSystem;
        message = "disko.bootImage.enableESP requires the ESP partition to define a vfat filesystem";
      }
    ];

    systemd.services = lib.optionalAttrs (enableESPRelocation && espHasFileSystem) {
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
        script = ''
          set -euo pipefail

          rootDevice="$(readlink -f ${
            lib.escapeShellArg config.fileSystems.${growPartitionMountPoint}.device
          })"
          parentDevice="$rootDevice"
          while [ "''${parentDevice%[0-9]}" != "''${parentDevice}" ]; do
            parentDevice="''${parentDevice%[0-9]}"
          done
          if [ "''${parentDevice%[0-9]p}" != "''${parentDevice}" ] && [ -b "''${parentDevice%p}" ]; then
            parentDevice="''${parentDevice%p}"
          fi

          espPartNum="${toString espPartition._index}"
          if [ "''${parentDevice%[0-9]}" != "$parentDevice" ]; then
            espDevice="$parentDevice"p"$espPartNum"
          else
            espDevice="$parentDevice$espPartNum"
          fi
          espBackup="/tmp/relocate-esp.img"

          dd if=${lib.escapeShellArg espContent.device} of="$espBackup" bs=4M conv=fsync status=none

          if findmnt --mountpoint ${lib.escapeShellArg espContent.mountpoint} >/dev/null 2>&1; then
            umount ${lib.escapeShellArg espContent.mountpoint}
          fi

          sgdisk --move-second-header "$parentDevice"
          sgdisk --delete="$espPartNum" "$parentDevice"
          sgdisk \
            --align-end \
            --new="$espPartNum:${espPartition.start}:${espPartition.end}" \
            --change-name="$espPartNum:${espPartition.label}" \
            --typecode="$espPartNum:${espPartition.type}" \
            --attributes="$espPartNum:=:0" \
            "$parentDevice"

          dd if="$espBackup" of="$espDevice" bs=4M conv=fsync status=none
          mkdir -p ${lib.escapeShellArg espContent.mountpoint}
          mount -t vfat ${espMountOptionArgs} "$espDevice" ${lib.escapeShellArg espContent.mountpoint}
          rm -f "$espBackup"
        '';
      };
    };
  };
}
