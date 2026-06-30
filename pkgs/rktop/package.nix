{
  lib,
  rustPlatform,
}:

rustPlatform.buildRustPackage {
  pname = "rktop";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./Cargo.lock
      ./Cargo.toml
      ./src
    ];
  };

  cargoLock = {
    lockFile = ./Cargo.lock;
  };

  meta = {
    description = "CPU/GPU monitor for Rockchip RK3588 systems on mainline Linux";
    license = lib.licenses.mit;
    mainProgram = "rktop";
    platforms = lib.platforms.linux;
    maintainers = with lib.maintainers; [ qbisi ];
  };
}
