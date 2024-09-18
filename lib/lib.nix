{ self
, inputs
, lib
, ...
}:
with lib;
rec {
  genAttrs' = items: v: listToAttrs (map (item: nameValuePair item.name (v item)) items);

  listNixFile =
    path: with builtins; filter (name: match "(.+)\\.nix" name != null) (attrNames (readDir path));

  listNixName = path: with builtins; map (file: head (match "(.+)\\.nix" file)) (listNixFile path);
}
