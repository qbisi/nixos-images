{ lib, buildLinux, fetchurl, fetchFromGitHub, ... }:
let
  version = "6.1.75-rkbsp-joshua";
  modDirVersion = "6.1.75";
  src = fetchFromGitHub {
    owner = "Joshua-Riek";
    repo = "linux-rockchip";
    rev = "Ubuntu-rockchip-6.1.0-1020.20";
    hash = "sha256-m8ZpkJvU1EKkDfTmOmzFbD/uFL1nxep/So4VqQRYlu0=";
  };
  _panthor_base = "aa54fa4e0712616d44f2c2f312ecc35c0827833d";
  _panthor_branch = "rk-6.1-rkr3-panthor";
  kernelPatches = [
    {
      name = "panthor";
      patch = fetchurl {
        url = "https://github.com/hbiyik/linux/compare/${_panthor_base}...${_panthor_branch}.patch";
        hash = "sha256-fDrl634LFH4Ou6Ky3dGit5WqASUvPlr9ngdb6a/wsss=";
      };
    }
    {
      name = "link-defconfig";
      patch = ./link-defconfig.patch;
    }
    {
      name = "gobinet-for-longsung";
      patch = ./gobinet-for-longsung.patch;
    }
    # {
    #   name = "serial-option-for-fm350";
    #   patch = ./serial-option-for-fm350.patch;
    # }
  ];
  defconfig = "linux_defconfig";
  structuredExtraConfig = with lib.kernel; {
    BTRFS_FS = yes;
    VIDEO_HANTRO = yes;
    STAGING_MEDIA = yes;
    VIDEO_ROCKCHIP_VDEC = yes;
  };
in
buildLinux {
  inherit src modDirVersion version defconfig;
  inherit kernelPatches;
  inherit structuredExtraConfig;
  autoModules = false;
  extraMakeFlags = [ "KCFLAGS=-march=armv8-a+crypto" ];
}

