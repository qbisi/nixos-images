{
  lib,
  stdenv,
  linux,
}:

stdenv.mkDerivation {
  pname = "sgm37604-backlight";
  version = "0-unstable-2026-05-13";

  src = lib.cleanSource ./.;

  nativeBuildInputs = linux.moduleBuildDependencies;

  makeFlags = [
    "KERNEL_DIR=${lib.getDev linux}/lib/modules/${linux.modDirVersion}/build"
  ];

  installPhase = ''
    runHook preInstall

    install -D sgm37604a.ko $out/lib/modules/${linux.modDirVersion}/extra/sgm37604a.ko

    runHook postInstall
  '';

  meta = {
    description = "SGM37604A I2C backlight kernel module";
    license = lib.licenses.gpl2Only;
    platforms = lib.platforms.linux;
    maintainers = with lib.maintainers; [ qbisi ];
  };
}
