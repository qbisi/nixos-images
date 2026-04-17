{ config, lib, ... }:
let
  cfg = config.disko.bootImage;
in
{
  config = lib.mkIf (config.disko.enableConfig && cfg.fileSystem == "ext4") {
    disko.bootImage._extraPartition = {
      nix = {
        size = "100%";
        start = lib.mkIf (cfg.primaryStart != null && !cfg.enableESP) cfg.primaryStart;
        content = {
          type = "filesystem";
          format = "ext4";
          mountpoint = "/";
        };
      };
    };
  };
}
