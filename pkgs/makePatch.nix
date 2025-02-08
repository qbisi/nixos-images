{ runCommand, ... }:
{
  name ? "unnamed",
  src,
  patchCommands,
}:
(runCommand "${name}.patch" { inherit src; } ''
  unpackPhase

  orig=$sourceRoot
  new=$sourceRoot-modded
  cp -r $orig/. $new/

  pushd $new >/dev/null
  ${patchCommands}
  popd >/dev/null

  diff -Naur $orig $new > $out || true
'')
