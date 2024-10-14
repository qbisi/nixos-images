{ config
, pkgs
, pkgs-self
, lib
, modulesPath
, inputs
, self
, ...
}:
{
  imports = [
    ./nixos-rockchip-h88k-uboot-btrfs.nix
  ];

  disko.profile = {
    partLabel = lib.mkForce "mmc";
    espStart = "16M";
    uboot.enable = true;
    uboot.package = pkgs-self.ubootHinlinkH88k;
  };

}
