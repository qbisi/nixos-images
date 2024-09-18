{ lib, callPackage, ... }: {
  linux_rkbsp_joshua = callPackage ./linux-rkbsp-joshua.nix { };
  linux_phytium_6_6 = callPackage ./linux-phytium-6.6.nix { };
}
