{
  lib,
  buildLinux,
  fetchgit,
  ...
}:
buildLinux {
  version = "6.6.0-phytium";
  modDirVersion = "6.6.0";

  src = fetchgit {
    url = "https://gitee.com/phytium_opensource/linux.git";
    tag = "Phytium-6.6.0";
    hash = "sha256-6u9VQdmKUrUOmE+K1z38pDwKmmb0LiUA7LeCl7oJmGw=";
  };

  kernelPatches = [
    {
      name = "libbpf-fix-discarded-qualifiers-under-c23";
      patch = ../patches/kernel/6.6/libbpf-fix-discarded-qualifiers-under-c23.patch;
    }
  ];

  structuredExtraConfig = with lib.kernel; {
    DRM_AST = yes;
  };

  extraMeta.platforms = [ "aarch64-linux" ];
}
