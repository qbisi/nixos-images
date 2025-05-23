{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.hardware.deviceTree;

  overlayType = lib.types.submodule {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        description = ''
          Name of this overlay
        '';
      };

      filter = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "*rpi*.dtb";
        description = ''
          Only apply to .dtb files matching glob expression.
        '';
      };

      dtsFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        description = ''
          Path to .dts overlay file, overlay is applied to
          each .dtb file matching "compatible" of the overlay.
        '';
        default = null;
        example = lib.literalExpression "./dts/overlays.dts";
      };

      dtsText = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Literal DTS contents, overlay is applied to
          each .dtb file matching "compatible" of the overlay.
        '';
        example = ''
          /dts-v1/;
          /plugin/;
          / {
                  compatible = "raspberrypi";
          };
          &{/soc} {
                  pps {
                          compatible = "pps-gpio";
                          status = "okay";
                  };
          };
        '';
      };

      dtboFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = ''
          Path to .dtbo compiled overlay file.
        '';
      };
    };
  };

  filteredKernelSource = lib.overrideDerivation (pkgs.srcOnly cfg.kernelPackage) (oldAttrs: {
    installPhase = ''
      mkdir -p $out
      rsync -avL scripts/dtc/include-prefixes/ $out \
        --include="${pkgs.stdenv.hostPlatform.linuxArch}/**" \
        --include="dt-bindings/**" \
        --exclude="*/**"
    '';
  });

  dtbFile =
    if (cfg.dtbFile != null) then
      cfg.dtbFile
    else if (cfg.dtsFile != null) then
      let
        includePaths =
          cfg.dtbBuildExtraIncludePaths
          ++ [ "${filteredKernelSource}" ]
          ++ lib.optional (
            cfg.platform != null
          ) "${filteredKernelSource}/${pkgs.stdenv.hostPlatform.linuxArch}/${cfg.platform}";
        extraPreprocessorFlags = cfg.dtbBuildExtraPreprocessorFlags;
      in
      pkgs.deviceTree.compileDTS {
        name = "${cfg.name}.dtb";
        inherit (cfg) dtsFile;
        inherit includePaths extraPreprocessorFlags;
      }
    else
      null;

  dtbSource =
    if (dtbFile == null) then
      cfg.dtbSource
    else
      pkgs.runCommand "single-dtb" { } ''
        install -D ${dtbFile} $out/${cfg.name}
      '';

  filterDTBs =
    src:
    if cfg.filter == null then
      src
    else
      pkgs.runCommand "dtbs-filtered" { } ''
        mkdir -p $out
        cd ${src}
        find . -type f -name '${cfg.filter}' -print0 \
          | xargs -0 cp -v --no-preserve=mode --target-directory $out --parents
      '';

  filteredDTBs = filterDTBs dtbSource;

  # Fill in `dtboFile` for each overlay if not set already.
  # Existence of one of these is guarded by assertion below
  withDTBOs =
    xs:
    lib.flip map xs (
      o:
      o
      // {
        dtboFile =
          let
            includePaths = [ "${filteredKernelSource}" ] ++ cfg.dtboBuildExtraIncludePaths;
            extraPreprocessorFlags = cfg.dtboBuildExtraPreprocessorFlags;
          in
          if o.dtboFile == null then
            let
              dtsFile = if o.dtsFile == null then (pkgs.writeText "dts" o.dtsText) else o.dtsFile;
            in
            pkgs.deviceTree.compileDTS {
              name = "${o.name}-dtbo";
              inherit includePaths extraPreprocessorFlags dtsFile;
            }
          else
            o.dtboFile;
      }
    );

in
{
  imports = [
    (lib.mkRemovedOptionModule [
      "hardware"
      "deviceTree"
      "base"
    ] "Use hardware.deviceTree.kernelPackage instead")
  ];

  options = {
    hardware.deviceTree = {
      enable = lib.mkOption {
        default = pkgs.stdenv.hostPlatform.linux-kernel.DTB or false;
        type = lib.types.bool;
        description = ''
          Build device tree files. These are used to describe the
          non-discoverable hardware of a system.
        '';
      };

      kernelPackage = lib.mkOption {
        default = config.boot.kernelPackages.kernel;
        defaultText = lib.literalExpression "config.boot.kernelPackages.kernel";
        example = lib.literalExpression "pkgs.linux_latest";
        type = lib.types.path;
        description = ''
          Kernel package where device tree include directory is from. Also used as default source of dtb package to apply overlays to
        '';
      };

      dtbBuildExtraPreprocessorFlags = lib.mkOption {
        default = [ ];
        example = lib.literalExpression "[ \"-DMY_DTB_DEFINE\" ]";
        type = lib.types.listOf lib.types.str;
        description = ''
          Additional flags to pass to the preprocessor during dtb compilations.
        '';
      };

      dtbBuildExtraIncludePaths = lib.mkOption {
        default = [ ];
        example = lib.literalExpression ''
          [
            \${cfg.kernelPackage.src}/arch/arm64/boot/dts/rockchip
          ]
        '';
        type = lib.types.listOf lib.types.path;
        description = ''
          Additional include paths that will be passed to the preprocessor when compiling the .dts into .dtb.
        '';
      };

      dtboBuildExtraPreprocessorFlags = lib.mkOption {
        default = [ ];
        example = lib.literalExpression "[ \"-DMY_DTB_DEFINE\" ]";
        type = lib.types.listOf lib.types.str;
        description = ''
          Additional flags to pass to the preprocessor during dtbo compilations
        '';
      };

      dtboBuildExtraIncludePaths = lib.mkOption {
        default = [ ];
        example = lib.literalExpression ''
          [
            ./my_custom_include_dir_1
            ./custom_include_dir_2
          ]
        '';
        type = lib.types.listOf lib.types.path;
        description = ''
          Additional include paths that will be passed to the preprocessor when creating the final .dts to compile into .dtbo
        '';
      };

      dtbSource = lib.mkOption {
        default = "${cfg.kernelPackage}/dtbs";
        defaultText = lib.literalExpression "\${cfg.kernelPackage}/dtbs";
        type = lib.types.path;
        description = ''
          Path to dtb directory that overlays and other processing will be applied to. Uses
          device trees bundled with the Linux kernel by default.
        '';
      };

      name = lib.mkOption {
        default = null;
        example = "some-dtb.dtb";
        type = lib.types.nullOr lib.types.str;
        description = ''
          The name of an explicit dtb to be loaded, relative to the dtb base.
          Useful in extlinux scenarios if the bootloader doesn't pick the
          right .dtb file from FDTDIR.
        '';
      };

      platform = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = lib.literalExpression ''
          Platform of this device.
          Path \${lib.getDev cfg.kernelPackage}/lib/modules/\${cfg.kernelPackage.modDirVersion}/source\
          /arch/\${pkgs.stdenv.hostPlatform.linuxArch}/boot/dts/\${cfg.platform} will be appended to
          dtbBuildExtraIncludePaths.
        '';
      };

      dtsFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        description = ''
          Path to .dts file
        '';
        default = null;
        example = lib.literalExpression "./dts/overlays.dts";
      };

      dtbFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = ''
          Path to .dtb compiled file
        '';
      };

      filter = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "*rpi*.dtb";
        description = ''
          Only include .dtb files matching glob expression.
        '';
      };

      overlays = lib.mkOption {
        default = [ ];
        example = lib.literalExpression ''
          [
            { name = "pps"; dtsFile = ./dts/pps.dts; }
            { name = "spi";
              dtsText = "...";
            }
            { name = "precompiled"; dtboFile = ./dtbos/example.dtbo; }
          ]
        '';
        type = lib.types.listOf (
          lib.types.coercedTo lib.types.path (path: {
            name = baseNameOf path;
            filter = null;
            dtboFile = path;
          }) overlayType
        );
        description = ''
          List of overlays to apply to base device-tree (.dtb) files.
        '';
      };

      package = lib.mkOption {
        default = null;
        type = lib.types.nullOr lib.types.path;
        internal = true;
        description = ''
          A path containing the result of applying `overlays` to `kernelPackage`.
        '';
      };

      filteredKernelSource = lib.mkOption {
        default = null;
        type = lib.types.nullOr lib.types.package;
        internal = true;
        description = ''
          Filtered kernel source for compiling out-of-tree dtbs .
        '';
      };
    };
  };

  config = lib.mkIf (cfg.enable) {

    assertions =
      let
        invalidOverlay = o: (o.dtsFile == null) && (o.dtsText == null) && (o.dtboFile == null);
      in
      [
        {
          assertion = lib.all (o: !invalidOverlay o) cfg.overlays;
          message = ''
            deviceTree overlay needs one of dtsFile, dtsText or dtboFile set.
            Offending overlay(s):
            ${toString (map (o: o.name) (builtins.filter invalidOverlay cfg.overlays))}
          '';
        }
        {
          assertion = cfg.dtsFile != null -> (cfg.name != null);
          message = ''
            deviceTree.dtsFile need deviceTree.name set.
          '';
        }
        {
          assertion = cfg.dtbFile != null -> (cfg.name != null);
          message = ''
            deviceTree.dtbFile need deviceTree.name set.
          '';
        }
      ];

    hardware.deviceTree.filteredKernelSource = filteredKernelSource;

    hardware.deviceTree.package =
      if (cfg.overlays != [ ]) then
        pkgs.deviceTree.applyOverlays filteredDTBs (withDTBOs cfg.overlays)
      else
        filteredDTBs;

    system.extraDependencies = lib.optional (cfg.filteredKernelSource != null) cfg.filteredKernelSource;
  };
}
