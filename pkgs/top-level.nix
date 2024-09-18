{ pkgs, ... }:
let
  callPackage = pkgs.newScope packages;
  packages = rec {
    inherit callPackage;
    linux-rkbsp-joshua = callPackage ./kernels/linux-rkbsp-joshua.nix { };
    linux-phytium-6_6 = callPackage ./kernels/linux-phytium-6.6.nix { };
  };
in
packages
