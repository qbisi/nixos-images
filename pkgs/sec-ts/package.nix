{
  lib,
  stdenv,
  linux,
}:

stdenv.mkDerivation {
  pname = "sec-ts";
  version = "0-unstable-2026-05-13";

  src = lib.cleanSource ./.;

  nativeBuildInputs = linux.moduleBuildDependencies;

  makeFlags = [
    "KERNEL_DIR=${lib.getDev linux}/lib/modules/${linux.modDirVersion}/build"
  ];

  installPhase = ''
    runHook preInstall

    install -D sec_ts.ko $out/lib/modules/${linux.modDirVersion}/kernel/sec_ts.ko

    runHook postInstall
  '';

  meta = {
    description = "Samsung SEC_TS I2C touchscreen kernel module";
    license = lib.licenses.gpl2Only;
    platforms = lib.platforms.linux;
    maintainers = with lib.maintainers; [ qbisi ];
  };
}
