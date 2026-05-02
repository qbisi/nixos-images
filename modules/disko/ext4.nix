{ config, lib, ... }:
let
  cfg = config.disko.bootImage;
in
{
  config = lib.mkIf (config.disko.enableConfig && cfg.fileSystem == "ext4") {
    disko.bootImage._primaryContent = {
      type = "filesystem";
      format = "ext4";
      mountpoint = "/";
    };
  };
}
