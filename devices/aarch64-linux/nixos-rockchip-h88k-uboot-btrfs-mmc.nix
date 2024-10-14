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

  disko = {
    profile.partLabel = lib.mkForce "mmc";
    profile.uboot.enable = true;
    profile.uboot.package = pkgs-self.ubootHinlinkH88k;
  };

}
