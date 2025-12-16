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
        default = "2300M";
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

      espStart = lib.mkOption {
        type = lib.types.nullOr (lib.types.strMatching "[0-9]+[KMGTP]?");
        default = null;
        example = "16M";
        description = "esp partition start size";
      };

      espSize = lib.mkOption {
        type = lib.types.strMatching "[0-9]+[KMGTP]?";
        default = "4M";
        description = "esp partition size";
      };

      _extraPartition = lib.mkOption {
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
    ];

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

              (lib.mkIf (cfg.type == "gpt") {
                ESP = {
                  start = lib.mkIf (cfg.espStart != null) cfg.espStart;
                  size = cfg.espSize;
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

              (lib.mkIf (cfg._extraPartition != null) cfg._extraPartition)
            ];
          };
        };
      };
    };
  };
}
