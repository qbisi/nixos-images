{
  lib,
  stdenv,
  linux,
}:

stdenv.mkDerivation {
  pname = "tcpci-husb311";
  version = "0-unstable-2026-05-27";

  src = lib.cleanSource ./.;

  nativeBuildInputs = linux.moduleBuildDependencies;

  makeFlags = [
    "KERNEL_DIR=${lib.getDev linux}/lib/modules/${linux.modDirVersion}/build"
  ];

  installPhase = ''
    runHook preInstall

    install -D tcpci_husb311.ko $out/lib/modules/${linux.modDirVersion}/kernel/tcpci_husb311.ko

    runHook postInstall
  '';

  meta = {
    description = "Hynetek HUSB311 TCPCI Type-C controller kernel module";
    license = lib.licenses.gpl2Only;
    platforms = lib.platforms.linux;
    maintainers = with lib.maintainers; [ qbisi ];
  };
}
