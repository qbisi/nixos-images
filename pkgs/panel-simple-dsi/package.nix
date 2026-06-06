{
  lib,
  stdenv,
  linux,
}:

stdenv.mkDerivation {
  pname = "panel-simple-dsi";
  version = "0-unstable-2026-05-13";

  src = lib.cleanSource ./.;

  nativeBuildInputs = linux.moduleBuildDependencies;

  makeFlags = [
    "KERNEL_DIR=${lib.getDev linux}/lib/modules/${linux.modDirVersion}/build"
  ];

  installPhase = ''
    runHook preInstall

    install -D panel-simple-dsi.ko $out/lib/modules/${linux.modDirVersion}/kernel/panel-simple-dsi.ko

    runHook postInstall
  '';

  meta = {
    description = "Generic simple MIPI DSI DRM panel kernel module";
    license = lib.licenses.gpl2Only;
    platforms = lib.platforms.linux;
    maintainers = with lib.maintainers; [ qbisi ];
  };
}
