{
  disko = {
    memSize = 4096;
    enableConfig = true;
    bootImage = {
      # efi only keep grub.efi such that it can be small
      espSize = "4M";
      efiSysMountPoint = "/boot/efi";
      imageSize = "2560M";
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
