{ config, lib, ... }:
let
  cfg = config.disko.bootImage;
in
{
  config = lib.mkIf (config.disko.enableConfig && config.disko.bootImage.fileSystem == "btrfs") {
    disko.bootImage._extraPartition = {
      nix = {
        size = "100%";
        start = lib.mkIf (cfg.primaryStart != null) cfg.primaryStart;
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
