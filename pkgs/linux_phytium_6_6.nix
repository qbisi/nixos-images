{
  lib,
  buildLinux,
  fetchFromGitHub,
  ...
}:
buildLinux {
  version = "6.6.0-phytium";
  modDirVersion = "6.6.0";

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

  extraMeta.platforms = [ "aarch64-linux" ];
}
