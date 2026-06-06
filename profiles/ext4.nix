{
  disko = {
    enableConfig = true;
    bootImage = {
      imageSize = "4G";
      primaryContent = {
        type = "filesystem";
        format = "ext4";
        mountpoint = "/";
      };
    };
  };
}
