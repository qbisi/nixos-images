{
  lib,
  config,
  self,
  ...
}:
{
  options = {
    system.symlinkConfig = {
      enable = lib.mkEnableOption "symlink config to generation profile";
    };
  };

  config = lib.mkIf config.system.symlinkConfig {
    system = {
      extraDependencies =
        let
          collector =
            parent:
            map (
              child:
              [ child.outPath ] ++ (if child ? inputs && child.inputs != { } then (collector child) else [ ])
            ) (lib.attrValues parent.inputs);
        in
        lib.unique (lib.flatten (collector self));

      systemBuilderCommands = lib.mkAfter ''
        mkdir -p $out/nixos-config
        ln -s ${self} $out/nixos-config
      '';
    };
  };
}
