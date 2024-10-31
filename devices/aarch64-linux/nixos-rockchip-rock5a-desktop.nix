{
  config,
  pkgs,
  pkgs-self,
  lib,
  modulesPath,
  inputs,
  self,
  ...
}:
{
  nixpkgs.system = "aarch64-linux";

  disko = {
    memSize = lib.mkForce 8192;
    profile.imageSize = "6G";
  };

  imports = [
    ./nixos-rockchip-rock5a.nix
    ../../modules/config/desktop.nix
  ];

}
