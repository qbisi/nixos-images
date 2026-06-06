{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.disko.bootImage;
in
{
  options = {
    disko.bootImage = {
      enableBiosBoot = lib.mkEnableOption "biosboot partition in gpt disk";

      enableCompression = lib.mkOption {
        type = lib.types.bool;
        default = if (builtins.getEnv "DISKO_COMPRESS" != "1") then false else true;
        description = "final disko image compression";
      };

      imageSize = lib.mkOption {
        type = lib.types.strMatching "[0-9]+[KMGTP]?";
        description = ''
          size of the image when disko images are created
          is used as an argument to "qemu-img create ..."
        '';
        default = "2G";
      };

      imageName = lib.mkOption {
        type = lib.types.str;
        description = "name for the disk images";
        default = "nixos-${config.nixpkgs.system}-${cfg.fileSystem}-${cfg.partLabel}";
      };

      partLabel = lib.mkOption {
        type = lib.types.str;
        default = if (builtins.getEnv "PARTLABEL" != "") then (builtins.getEnv "PARTLABEL") else "main";
        example = "nvme";
        description = ''
          Disko use partLabel to identify and mount disk, use different partLabel
          for different media.
        '';
      };

      primaryStart = lib.mkOption {
        type = lib.types.nullOr (lib.types.strMatching "[0-9]+[KMGTP]?");
        default = null;
        example = "16M";
        description = "primary partition start seek";
      };

      espSize = lib.mkOption {
        type = lib.types.strMatching "[0-9]+[KMGTP]?";
        default = "4M";
        description = "esp partition size";
      };

      efiSysMountPoint = lib.mkOption {
        default = "/boot/efi";
        type = lib.types.str;
        description = "Where the EFI System Partition is mounted.";
      };

      primaryContent = lib.mkOption {
        type = lib.types.nullOr lib.types.attrs;
        default = null;
      };
    };
  };

  config = lib.mkIf (config.disko.enableConfig && cfg.primaryContent != null) {
    boot.loader = {
      efi.efiSysMountPoint = cfg.efiSysMountPoint;
      grub = {
        device = if cfg.enableBiosBoot then config.disko.devices.disk.main.device else "nodev";
        efiSupport = true;
        efiInstallAsRemovable = true;
      };
    };

    disko = {
      imageBuilder.extraPostVM = lib.mkIf cfg.enableCompression (
        lib.mkAfter ''
          ${config.disko.imageBuilder.pkgs.xz}/bin/xz -z $out/${cfg.imageName}.${config.disko.imageBuilder.imageFormat}
        ''
      );

      devices = {
        disk.main = {
          name = cfg.partLabel;
          imageName = cfg.imageName;
          imageSize = cfg.imageSize;
          device = "/dev/disk/by-diskseq/1";
          type = "disk";
          content = {
            type = "gpt";
            partitions = lib.mkMerge [
              (lib.mkIf cfg.enableBiosBoot {
                boot = {
                  size = "1M";
                  type = "EF02";
                  priority = 0;
                };
              })

              {
                ESP = {
                  start = "-${cfg.espSize}";
                  size = cfg.espSize;
                  alignment = 1;
                  type = "EF00";
                  priority = 1;
                  content = {
                    type = "filesystem";
                    format = "vfat";
                    mountpoint = cfg.efiSysMountPoint;
                    mountOptions = [
                      "fmask=0077"
                      "dmask=0077"
                    ];
                  };
                };
                nix = {
                  start = lib.mkIf (cfg.primaryStart != null) cfg.primaryStart;
                  size = "100%";
                  content = cfg.primaryContent;
                };
              }
            ];
          };
        };
      };
    };
  };
}
