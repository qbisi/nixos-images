{ lib
, config
, pkgs
, ...
}:
with lib;
let
  cfg = config.disko.profile;
in
{
  options = {
    disko.profile = {
      use = mkOption {
        type = types.str;
        default = "";
        description = "disko preset profile to use";
      };

      platform = mkOption {
        type = types.str;
        default = config.nixpkgs.system;
        description = "Device platform, use for image naming.";
      };

      enableBiosBoot = mkEnableOption "biosboot partition in gpt disk";

      imageSize = mkOption {
        type = types.strMatching "[0-9]+[KMGTP]?";
        description = ''
          size of the image when disko images are created
          is used as an argument to "qemu-img create ..."
        '';
        default = "2G";
      };

      imageName = mkOption {
        type = types.str;
        description = "name for the disk images";
        default = "nixos-${cfg.platform}-${cfg.use}-${cfg.partlabel}";
      };

      partLabel = mkOption {
        type = types.str;
        default = "scsi";
        example = "nvme";
        description = ''
          Disko use partlabel to identify and mount disk, use different partlabel
          for different media.
        '';
      };

      type = mkOption {
        type = types.str;
        default = "gpt";
        description = ''
          disk partition type
        '';
      };

      espStart = mkOption {
        type = types.nullOr (types.strMatching "[0-9]+[KMGTP]?");
        default = null;
        example = "16M";
        description = "esp partition start size";
      };

      espSize = mkOption {
        type = types.strMatching "[0-9]+[KMGTP]?";
        default = "4M";
        description = "esp partition size";
      };

      _extraPartition = mkOption
        {
          type = types.nullOr types.attrs;
          internal = true;
          default = null;
        };

    };
  };

  config = mkIf (config.disko.enableConfig && cfg.use != "") {
    assertions = [
      {
        assertion = cfg.enableBiosBoot -> cfg.type == "gpt";
        message = "biosboot partition requires gpt disk type.";
      }
    ];

    disko = {
      extraPostVM =
        let
          oldImageName = "${config.disko.devices.disk.main.name}.raw";
          newImageName = "${cfg.imageName}.raw";
        in
        ''
          mv "$out/${oldImageName}" "$out/${newImageName}"
          ${pkgs.xz}/bin/xz -z "$out/${newImageName}"
        '';
      devices = {
        disk.main = {
          name = cfg.partLabel;
          imageSize = cfg.imageSize;
          device =
            let
              device = config.boot.loader.grub.device;
            in
            if (device != "nodev") then device else "/dev/disk/by-diskseq/1";
          type = "disk";
          content = {
            type = cfg.type;
            partitions = mkMerge [
              (mkIf cfg.enableBiosBoot {
                boot = {
                  size = "1M";
                  type = "EF02";
                  priority = 0;
                };
              })

              (mkIf (cfg.type == "gpt")
                {
                  ESP = {
                    start = mkIf (cfg.espStart != null) cfg.espStart;
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

              (mkIf (cfg._extraPartition != null) cfg._extraPartition)
            ];
          };
        };
      };
    };
  };
}
