self: pkgs: {
  makePatch =
    {
      name ? "unnamed",
      src,
      patchCommands,
    }:
    pkgs.runCommand "${name}.patch" { inherit src; } ''
      unpackPhase

      orig=$sourceRoot
      new=$sourceRoot-modded
      cp -r $orig/. $new/

      pushd $new >/dev/null
      ${patchCommands}
      popd >/dev/null

      diff -Naur $orig $new > $out || true
    '';

  buildUBoot =
    { defconfig, ... }@args:
    (pkgs.buildUBoot args).overrideAttrs {
      configurePhase = ''
        runHook preConfigure

        cat $extraConfigPath >> configs/${defconfig}

        make ${defconfig}

        runHook postConfigure
      '';
    };

  buildLinux =
    let
      kernalArch =
        if pkgs.stdenv.hostPlatform.linuxArch == "x86_64" then
          "x86"
        else
          pkgs.stdenv.hostPlatform.linuxArch;
    in
    {
      defconfigFile ? null,
      defconfig ? if isNull defconfigFile then null else "fromfile_defconfig",
      kernelPatches ? [],
      ...
    }@args:
    (pkgs.buildLinux args).override {
      inherit defconfig;
      kernelPatches =
        kernelPatches
        ++ pkgs.lib.optional (!(isNull defconfig)) {
          name = "symlink-defconfigFile-to-kernel-defconfig";
          patch = self.makePatch {
            src = pkgs.emptyDirectory;
            patchCommands = ''
              mkdir -p arch/${kernalArch}/configs
              ln -s ${defconfigFile} arch/${kernalArch}/configs/${defconfig}
            '';
          };
        };
    };
}
