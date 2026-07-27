lib: {
  patchesIn =
    directory:
    lib.mapAttrsToList
      (name: _: {
        inherit name;
        patch = directory + "/${name}";
      })
      (
        lib.filterAttrs (
          name: type:
          lib.elem type [
            "regular"
            "symlink"
          ]
          && lib.hasSuffix ".patch" name
        ) (builtins.readDir directory)
      );
}
