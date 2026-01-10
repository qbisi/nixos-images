{
  lib,
  buildLinux,
  fetchurl,
  fetchFromGitHub,
  armbianBuild,
  ...
}:
let
  version = "6.1.118-armbian";
  modDirVersion = "6.1.118";
  src = fetchFromGitHub {
    owner = "armbian";
    repo = "linux-rockchip";
    rev = "b67dc5c9ade9dc354b790eb64aa6a665d0a54ecd";
    hash = "sha256-xSZ63aUR78V92eD9X+rEYl0+1jRG1lBwhGhE2xjIn2U=";
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
