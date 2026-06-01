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

      enableESP = lib.mkEnableOption "efi partition in gpt disk" // {
        default = true;
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
        default = "main";
        example = "nvme";
        description = ''
          Disko use partlabel to identify and mount disk, use different partlabel
          for different media.
        '';
      };

      type = lib.mkOption {
        type = lib.types.str;
        default = "gpt";
        description = ''
          disk partition type.
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

      _primaryContent = lib.mkOption {
        type = lib.types.nullOr lib.types.attrs;
        internal = true;
        default = null;
      };
    };
  };

  config = lib.mkIf (config.disko.enableConfig && cfg.fileSystem != null) {
    assertions = [
      {
        assertion = cfg.enableBiosBoot -> cfg.type == "gpt";
        message = "biosboot partition requires gpt disk type.";
      }
      {
        assertion = cfg.enableESP -> cfg.type == "gpt";
        message = "efi partition requires gpt disk type.";
      }
    ];

    boot.loader = lib.mkIf cfg.enableESP {
      efi.efiSysMountPoint = "/boot/efi";
      grub = {
        efiSupport = true;
        efiInstallAsRemovable = true;
      };
    };

    disko = {
      memSize = lib.mkDefault 4096;

      imageBuilder = {
        enableBinfmt = true;
        kernelPackages = config.disko.imageBuilder.pkgs.linuxPackages;
        extraPostVM = lib.mkAfter ''
          ${config.disko.imageBuilder.pkgs.xz}/bin/xz -z $out/*${config.disko.imageBuilder.imageFormat}
        '';
      };

      bootImage.partLabel = lib.mkIf (builtins.getEnv "PARTLABEL" != "") (
        lib.mkForce (builtins.getEnv "PARTLABEL")
      );

      devices = {
        disk.main = {
          name = cfg.partLabel;
          imageName = cfg.imageName;
          imageSize = cfg.imageSize;
          device =
            let
              device = config.boot.loader.grub.device;
            in
            if (device != "nodev") then device else "/dev/disk/by-diskseq/1";
          type = "disk";
          content = {
            type = cfg.type;
            partitions = lib.mkMerge [
              (lib.mkIf cfg.enableBiosBoot {
                boot = {
                  size = "1M";
                  type = "EF02";
                  priority = 0;
                };
              })

              (lib.mkIf cfg.enableESP {
                ESP = {
                  start = "-${cfg.espSize}";
                  size = "100%";
                  type = "EF00";
                  priority = 1;
                  content = {
                    type = "filesystem";
                    format = "vfat";
                    mountpoint = "/boot/efi";
                    mountOptions = [
                      "fmask=0077"
                      "dmask=0077"
                    ];
                  };
                };
              })

              (lib.mkIf (cfg._primaryContent != null) {
                nix = {
                  start = lib.mkIf (cfg.primaryStart != null) cfg.primaryStart;
                  size = "100%";
                  content = cfg._primaryContent;
                };
              })
            ];
          };
        };
      };
    };
  };
}
