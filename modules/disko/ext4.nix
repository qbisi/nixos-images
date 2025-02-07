{ config, lib, ... }:
with lib;
{
  config = mkIf (config.disko.enableConfig && config.disko.profile.use == "ext4") {
    disko.profile._extraPartition = {
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
