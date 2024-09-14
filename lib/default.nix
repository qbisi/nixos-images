{
  self,
  inputs,
  lib,
  ...
}:
{
  flake = {
    lib = import ./lib.nix { inherit self inputs lib; };
  };
}
