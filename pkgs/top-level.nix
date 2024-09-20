{ pkgs, ... }:
let
  callPackage = pkgs.newScope packages;
  packages = rec {
    linux_rkbsp_joshua = callPackage ./kernels/linux-rkbsp-joshua.nix { };
    linux_phytium_6_6 = callPackage ./kernels/linux-phytium-6.6.nix { };
    mali-panthor-g610-firmware = callPackage ./mali-panthor-g610-firmware.nix { };
    makePatch = callPackage ../pkgs/makePatch.nix { };
    inherit (callPackage ./u-boot { })
      ubootHinlinkH88k
      ubootRock5ModelB
      ubootBozzSW799;
  };
in
packages
