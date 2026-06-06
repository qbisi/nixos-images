{
  lib,
  symlinkJoin,
  alsa-ucm-conf,
}:
symlinkJoin {
  name = "alsa-ucm-conf-rk3588";
  paths = [
    alsa-ucm-conf
    (lib.fileset.toSource {
      root = ./.;
      fileset = lib.fileset.unions [
        ./share
      ];
    })
  ];
}
