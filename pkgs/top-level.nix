{ pkgs, ... }:
let
  callPackage = pkgs.newScope packages;
  packages = rec {
    linux_rkbsp_joshua = callPackage ./kernels/linux-rkbsp-joshua.nix { };
    linux_phytium_6_6 = callPackage ./kernels/linux-phytium-6.6.nix { };
    mali_panthor_g610-firmware = callPackage ./mali-panthor-g610-firmware.nix { };
    brcmfmac_sdio-firmware = callPackage ./brcmfmac_sdio-firmware.nix { };
    makePatch = callPackage ../pkgs/makePatch.nix { };
    inherit (callPackage ./u-boot { })
      ubootHinlinkH88k
      ubootOrangePi5
      ubootOrangePi5Plus
      ubootNanoPCT6
      ubootRock5ModelB
      ubootRock5ModelA
      ubootBozzSW799
      ubootCdhxRb30
      ;
  };
in
packages
