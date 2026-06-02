{
  disko = {
    memSize = 4096;
    enableConfig = true;
    bootImage = {
      imageSize = "2G";
      primaryContent = {
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
}
