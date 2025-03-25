{
  lib,
  buildLinux,
  fetchurl,
  fetchFromGitHub,
  armbianBuild,
  ...
}:
let
  version = "6.1.75-armbian";
  modDirVersion = "6.1.75";
  src = fetchFromGitHub {
    owner = "armbian";
    repo = "linux-rockchip";
    rev = "v24.11.1";
    hash = "sha256-ZqEKQyFeE0UXN+tY8uAGrKgi9mXEp6s5WGyjVuxmuyM=";
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
}
