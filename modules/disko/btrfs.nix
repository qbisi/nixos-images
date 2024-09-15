{ config, lib, ... }:
{
  options = {
    disko.biosboot.enable = lib.mkOption {
      default = false;
      example = true;
      type = lib.types.bool;
      description = ''
        Whether to enable biosboot part in gptdisk
      '';
    };
  };

  config =
    let
      device = config.boot.loader.grub.device;
    in
    {
      disko = {
        enableConfig = true;
        devices = {
          disk.main = {
            name = config.disko.type;
            imageSize = "2G";
            device = if (device != "") then device else "/dev/disk/by-diskseq/1";
            type = "disk";
            content = {
              type = "gpt";
              partitions = (lib.optionalAttrs config.disko.biosboot.enable {
                boot = {
                  size = "1M";
                  type = "EF02";
                  priority = 0;
                };
              }) // {
                ESP = {
                  name = "ESP";
                  size = "4M";
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
                nix = {
                  size = "100%";
                  content = {
                    type = "btrfs";
                    extraArgs = [ "-f" ];
                    subvolumes = {
                      "/" = {
                        mountOptions = [ "noatime" ];
                        mountpoint = "/.btrfs_root";
                      };
                      "/@" = {
                        mountOptions = [
                          "compress=zstd"
                          "noatime"
                        ];
                        mountpoint = "/";
                      };
                      "/@var" = {
                        mountOptions = [
                          "compress=zstd"
                          "noatime"
                        ];
                        mountpoint = "/var";
                      };
                      "/@home" = {
                        mountOptions = [
                          "compress=zstd"
                          "noatime"
                        ];
                        mountpoint = "/home";
                      };
                      "/@swap" = {
                        mountpoint = "/swap";
                      };
                    };
                  };
                };
              };
            };
          };
        };
      };
    };
}
