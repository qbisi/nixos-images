{
  lib,
  buildLinux,
  fetchFromGitHub,
  ...
}:
let
  version = "6.6.2-phytium";
  modDirVersion = "6.6.2";
  src = fetchFromGitHub {
    githubBase = "gitee.com";
    owner = "phytium_opensource";
    repo = "linux";
    rev = "Phytium-6.6.2";
    forceFetchGit = true;
    hash = "sha256-gzm/lmqQdIiTkhtzbj6/tHg1I8PrY9RznUpTO8+l1dE=";
  };
  structuredExtraConfig = with lib.kernel; {
    DRM_AST = yes;
  };
in
buildLinux {
  inherit src modDirVersion version;
  inherit structuredExtraConfig;
}
