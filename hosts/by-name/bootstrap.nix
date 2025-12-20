{
  config,
  pkgs,
  lib,
  self,
  inputs,
  ...
}:
{
  imports = [
    "${self}/devices/by-name/nixos-aarch64-uefi.nix"
    self.nixosModules.bootstrap
  ];

  networking.hostName = "bootstrap";
}
