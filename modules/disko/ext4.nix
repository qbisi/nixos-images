{ config, lib, ... }:
{
  config = lib.mkIf (config.disko.enableConfig && config.disko.bootImage.fileSystem == "ext4") {
    disko.bootImage._extraPartition = {
      nix = {
        size = "100%";
        content = {
          type = "filesystem";
          format = "ext4";
          mountpoint = "/";
        };
      };
    };
  };
}
