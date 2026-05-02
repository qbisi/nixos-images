# This module automatically grows the root partition.
# This allows an instance to be created with a bigger root filesystem
# than provided by the machine image.

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.boot.growPartition;
  relocateESP = config.systemd.services.relocate-esp.enable or false;
  rootFsType = config.fileSystems.${cfg.mountPoint}.fsType or null;
  rootIsBtrfs = rootFsType == "btrfs";
  rootIsExt = builtins.elem rootFsType [
    "ext2"
    "ext3"
    "ext4"
  ];
in

{

  disabledModules = [ "system/boot/grow-partition.nix" ];

  imports = [
    (lib.mkRenamedOptionModule [ "virtualisation" "growPartition" ] [ "boot" "growPartition" "enable" ])
  ];

  options = {
    boot.growPartition = {
      enable = lib.mkEnableOption "growing the root partition on boot";

      mountPoint = lib.mkOption {
        default = "/";
        example = "/nix";
        type = lib.types.str;
        description = ''
          This is the mount point of your rootDevice. Used when building a stateless image.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !config.boot.initrd.systemd.repart.enable && !config.systemd.repart.enable;
        message = "systemd-repart already grows the root partition and thus you should not use boot.growPartition";
      }
      {
        assertion = lib.hasAttr cfg.mountPoint config.fileSystems;
        message = "your rootDevice on the mount point ${cfg.mountPoint} does not exists";
      }
    ];
    systemd.services.growpart = {
      wantedBy = [ "-.mount" ];
      requires = lib.optional relocateESP "relocate-esp.service";
      after = [ "-.mount" ] ++ lib.optional relocateESP "relocate-esp.service";
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
        [ cloud-utils.guest ] ++ lib.optional rootIsBtrfs btrfs-progs ++ lib.optional rootIsExt e2fsprogs;
      script = ''
        rootDevice="${config.fileSystems.${cfg.mountPoint}.device}"
        rootDevice="$(readlink -f "$rootDevice")"
        parentDevice="$rootDevice"
        while [ "''${parentDevice%[0-9]}" != "''${parentDevice}" ]; do
          parentDevice="''${parentDevice%[0-9]}";
        done
        partNum="''${rootDevice#"''${parentDevice}"}"
        if [ "''${parentDevice%[0-9]p}" != "''${parentDevice}" ] && [ -b "''${parentDevice%p}" ]; then
          parentDevice="''${parentDevice%p}"
        fi
        growpart "$parentDevice" "$partNum"
      ''
      + lib.optionalString rootIsExt ''
        resize2fs "$rootDevice"
      ''
      + lib.optionalString rootIsBtrfs ''
        btrfs filesystem resize max ${cfg.mountPoint}
      '';
    };
  };
}
