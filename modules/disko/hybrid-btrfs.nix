{config, ...}:
{
  disko = {
    enableConfig = true;
    devices = {
      disk.${config.disko.label} = {
        imageSize = "2G";
        device = "/dev/disk/by-diskseq/1";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            boot = {
              size = "1M";
              type = "EF02";
              priority = 0;
            };
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
}
