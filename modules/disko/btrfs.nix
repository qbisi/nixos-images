{ config, lib, ... }:
with lib;
{
  config = mkIf (config.disko.enableConfig && config.disko.profile.use == "btrfs") {
    disko.profile._extraPartition = {
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
}
