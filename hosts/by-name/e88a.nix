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
    targetHost = config.networking.hostName;
    buildOnTarget = false;
    tags = [ "rk3588" ];
    sshOptions = [ "-o ConnectionAttempts=2" ];
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
