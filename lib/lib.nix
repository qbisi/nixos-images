{
  self,
  inputs,
  lib,
  ...
}:
with lib;
rec {
  genAttrs' = items: v: listToAttrs (map (item: nameValuePair item.name (v item)) items);

  listNixfile =
    path: with builtins; filter (name: match "(.+)\\.nix" name != null) (attrNames (readDir path));

  listNixname = path: with builtins; map (file: head (match "(.+)\\.nix" file)) (listNixfile path);
}
