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
    memSize = 8192;
  };

  imports = [
    ./nixos-rockchip-h88k.nix
    ../../modules/config/desktop.nix
  ];

}
