{
  pkgs,
  ...
}:
{
  imports = [
    ../common.nix
  ];

  nixpkgs = {
    system = "aarch64-linux";
  };

  disko = {
    bootImage.fileSystem = "btrfs";
  };

  boot = {
    kernelPackages = pkgs.linuxPackagesFor pkgs.linux_phytium_6_6;
  };
}
