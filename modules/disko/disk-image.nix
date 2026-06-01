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
  imports = [
    ./ext4.nix
    ./btrfs.nix
    ./uboot.nix
  ];

  options = {
    disko.bootImage = {
      fileSystem = lib.mkOption {
        type = lib.types.nullOr (
          lib.types.enum [
            "ext4"
            "btrfs"
          ]
        );
        default = null;
        description = "disko preset bootImage to use";
      };

      enableBiosBoot = lib.mkEnableOption "biosboot partition in gpt disk";

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
        default = "main";
        example = "nvme";
        description = ''
          Disko use partlabel to identify and mount disk, use different partlabel
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

      _primaryContent = lib.mkOption {
        type = lib.types.nullOr lib.types.attrs;
        internal = true;
        default = null;
      };
    };
  };

  config = lib.mkIf (config.disko.enableConfig && cfg.fileSystem != null) {
    boot.loader = {
      efi.efiSysMountPoint = cfg.efiSysMountPoint;
      grub = {
        device = lib.mkIf cfg.enableBiosBoot config.disko.devices.disk.main.device;
        efiSupport = true;
        efiInstallAsRemovable = true;
      };
    };

    disko = {
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
                  content = cfg._primaryContent;
                };
              }
            ];
          };
        };
      };
    };
  };
}
