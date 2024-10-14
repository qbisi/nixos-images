{ lib, buildLinux, fetchFromGitHub, ... }:
let
  version = "6.6.0-phytium";
  modDirVersion = "6.6.0";
  src = fetchFromGitHub {
    githubBase = "gitee.com";
    owner = "phytium_opensource";
    repo = "linux";
    rev = "Phytium-6.6.0";
    forceFetchGit = true;
    hash = "sha256-6u9VQdmKUrUOmE+K1z38pDwKmmb0LiUA7LeCl7oJmGw=";
  };
  structuredExtraConfig = with lib.kernel; {
    DRM_AST = yes; 
  };
in
buildLinux {
  inherit src modDirVersion version;
  inherit structuredExtraConfig;
}

