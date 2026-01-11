{
  lib,
  buildLinux,
  fetchurl,
  fetchFromGitHub,
  armbianBuild,
  ...
}:
let
  version = "6.1.115-armbian";
  modDirVersion = "6.1.115";
  src = fetchFromGitHub {
    owner = "armbian";
    repo = "linux-rockchip";
    rev = "b908c7339f51eddcfe8402cd15d1e1f8f4e67c29";
    hash = "sha256-70wGP16SJHs7I8HklhNdrJbWzfvcgJCupgfOq81e1U8=";
  };
  defconfigFile = "${armbianBuild}/config/kernel/linux-rk35xx-vendor.config";
in
buildLinux {
  inherit
    src
    modDirVersion
    version
    defconfigFile
    ;
  enableCommonConfig = false;
  extraConfig = "";
  ignoreConfigErrors = true;
  autoModules = false;
  extraMakeFlags = [ "KCFLAGS=-march=armv8-a+crypto" ];
}
