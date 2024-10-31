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
    ./nixos-rockchip-h88k.nix
    ../../modules/config/desktop.nix
  ];

}
