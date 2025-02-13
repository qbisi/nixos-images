{ pkgs, ... }:
let
  callPackage = pkgs.newScope packages;
  packages = rec {
    linux_rkbsp_joshua = callPackage ./kernels/linux-rkbsp-joshua.nix { };
    linux_phytium_6_6 = callPackage ./kernels/linux-phytium-6.6.nix { };
    linux_rockchip64_6_13 = callPackage ./kernels/linux-rockchip64-6.13.nix { };
    linux_rockchip64_6_12 = callPackage ./kernels/linux-rockchip64-6.12.nix { };
    mali_panthor_g610-firmware = callPackage ./mali-panthor-g610-firmware.nix { };
    brcmfmac_sdio-firmware = callPackage ./brcmfmac_sdio-firmware.nix { };
    makePatch = callPackage ../pkgs/makePatch.nix { };
    inherit (callPackage ./u-boot { })
      ubootHinlinkH88k
      # ubootOrangePi5
      # ubootOrangePi5Plus
      # ubootNanoPCT6
      # ubootRock5ModelB
      # ubootRock5ModelA
      ubootBozzSW799
      ubootCdhxRb30
      ;
    inherit (pkgs) armTrustedFirmwareRK3588 ubootOrangePi5Plus;
    armbian-firmware = callPackage ./firmware/armbian-firmware.nix { };
  };
in
packages
