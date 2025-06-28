{
  config,
  pkgs,
  lib,
  self,
  inputs,
  ...
}:
{
  deployment = {
    # targetHost = config.networking.hostName;
    targetHost = "192.168.100.188";
    buildOnTarget = false;
  };

  imports = [
    "${self}/devices/by-name/nixos-jea-e88a.nix"
    self.nixosModules.bootstrap
  ];

  boot.loader.grub.btrfsPackage = lib.mkForce pkgs.btrfs-progs;

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
  };
}
