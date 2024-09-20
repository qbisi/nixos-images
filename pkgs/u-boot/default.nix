{ stdenv
, lib
, bc
, bison
, dtc
, fetchFromGitHub
, fetchpatch
, fetchurl
, flex
, gnutls
, installShellFiles
, libuuid
, meson-tools
, ncurses
, openssl
, rkbin
, swig
, which
, python3
, armTrustedFirmwareAllwinner
, armTrustedFirmwareAllwinnerH6
, armTrustedFirmwareAllwinnerH616
, armTrustedFirmwareRK3328
, armTrustedFirmwareRK3399
, armTrustedFirmwareRK3588
, armTrustedFirmwareS905
, buildPackages
, makePatch
, gcc12Stdenv
}:
let
  defaultVersion = "2024.07";
  defaultSrc = fetchurl {
    url = "https://ftp.denx.de/pub/u-boot/u-boot-${defaultVersion}.tar.bz2";
    hash = "sha256-9ZHamrkO89az0XN2bQ3f+QxO1zMGgIl0hhF985DYPI8=";
  };

  # Dependencies for the tools need to be included as either native or cross,
  # depending on which we're building
  toolsDeps = [
    ncurses # tools/kwboot
    libuuid # tools/mkeficapsule
    gnutls # tools/mkeficapsule
    openssl # tools/mkimage
  ];

  buildUBoot = lib.makeOverridable ({ version ? null
                                    , src ? null
                                    , filesToInstall
                                    , pythonScriptsToInstall ? { }
                                    , installDir ? "$out"
                                    , defconfig
                                    , extraConfig ? ""
                                    , extraPatches ? [ ]
                                    , extraMakeFlags ? [ ]
                                    , extraMeta ? { }
                                    , crossTools ? false
                                    , stdenv ? gcc12Stdenv
                                    , ...
                                    } @ args: stdenv.mkDerivation ({
    pname = "uboot-${defconfig}";

    version = if src == null then defaultVersion else version;

    src = if src == null then defaultSrc else src;

    patches = extraPatches;

    postPatch = ''
      { echo "";cat $extraConfigPath; } >> ./configs/${defconfig}
      ${lib.concatMapStrings (script: ''
        substituteInPlace ${script} \
        --replace "#!/usr/bin/env python3" "#!${pythonScriptsToInstall.${script}}/bin/python3"
      '') (builtins.attrNames pythonScriptsToInstall)}
      patchShebangs tools
      patchShebangs scripts
    '';

    nativeBuildInputs = [
      ncurses # tools/kwboot
      bc
      bison
      flex
      installShellFiles
      (buildPackages.python3.withPackages (p: [
        p.libfdt
        p.setuptools # for pkg_resources
        p.pyelftools
      ]))
      swig
      which # for scripts/dtc-version.sh
    ] ++ lib.optionals (!crossTools) toolsDeps;
    depsBuildBuild = [ stdenv.cc ];
    buildInputs = lib.optionals crossTools toolsDeps;

    hardeningDisable = [ "all" ];

    enableParallelBuilding = true;

    makeFlags = [
      "DTC=${lib.getExe buildPackages.dtc}"
      "CROSS_COMPILE=${stdenv.cc.targetPrefix}"
    ] ++ extraMakeFlags;

    passAsFile = [ "extraConfig" ];

    configurePhase = ''
      runHook preConfigure

      make ${defconfig}

      runHook postConfigure
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p ${installDir}
      cp ${lib.concatStringsSep " " (filesToInstall ++ builtins.attrNames pythonScriptsToInstall)} ${installDir}

      mkdir -p "$out/nix-support"
      ${lib.concatMapStrings (file: ''
        echo "file binary-dist ${installDir}/${builtins.baseNameOf file}" >> "$out/nix-support/hydra-build-products"
      '') (filesToInstall ++ builtins.attrNames pythonScriptsToInstall)}

      runHook postInstall
    '';

    dontStrip = true;

    meta = with lib; {
      homepage = "https://www.denx.de/wiki/U-Boot/";
      description = "Boot loader for embedded systems";
      license = licenses.gpl2Plus;
      maintainers = with maintainers; [ bartsch dezgeg lopsided98 ];
    } // extraMeta;
  } // removeAttrs args [ "extraMeta" "pythonScriptsToInstall" ]));
  ubootRockchip =
    { defconfig
    , deviceTree ? null
    , ROCKCHIP_TPL ? null
    , manufacturer ? null
    , product ? null
    , version ? null
    , family ? null
    , smbiosSupport ? true
    , videoSupport ? true
    , drmSupport ? false
    , efiSupport ? true
    , nvmeSupport ? true
    , usbSupport ? true
    , keyboardSupport ? true
    , preBootsupport ? usbSupport || nvmeSupport
    , extraConfig ? ""
    , extraPatches ? [ ]
    , ...
    }@args:
      assert keyboardSupport -> usbSupport;
      assert drmSupport -> videoSupport;
      assert (!isNull manufacturer) -> smbiosSupport;
      assert (!isNull product) -> smbiosSupport;
      assert (!isNull version) -> smbiosSupport;
      assert (!isNull family) -> smbiosSupport;
      let
        upstreamSrc = with lib.fileset; toSource {
          root = ../../dts/kernel;
          fileset = ../../dts/kernel;
        };
        ubootSrc = with lib.fileset; toSource {
          root = ../../dts/u-boot;
          fileset = ../../dts/u-boot;
        };
        dts-u-boot-patch1 = makePatch { src = upstreamSrc; prefix = "dts/upstream/src/arm64/rockchip"; };
        dts-u-boot-patch2 = makePatch { src = ubootSrc; prefix = "arch/arm/dts"; };
        preBootcommand = lib.optionalString nvmeSupport "pci enum;nvme scan;"
          + lib.optionalString usbSupport "usb start;";
      in
      (buildUBoot ({
        inherit defconfig;
        extraPatches = [
          ./add-smbios-config.patch
          ./rk3399-devicetree-display-subsystem-add-label.patch
          ./drm.patch
          dts-u-boot-patch1
          dts-u-boot-patch2
        ] ++ extraPatches;
        extraConfig = lib.optionalString (!isNull deviceTree) ''
          CONFIG_DEFAULT_DEVICE_TREE="${deviceTree}"
          CONFIG_DEFAULT_FDT_FILE="${deviceTree}.dtb"
        '' + lib.optionalString smbiosSupport (''
          CONFIG_SYSINFO=y
          CONFIG_SYSINFO_SMBIOS=y
        '' + lib.optionalString (!isNull manufacturer) ''
          CONFIG_SYSINFO_SMBIOS_MANUFACTURER="${manufacturer}"
        '' + lib.optionalString (!isNull product) ''
          CONFIG_SYSINFO_SMBIOS_PRODUCT="${product}"
        '' + lib.optionalString (!isNull version) ''
          CONFIG_SYSINFO_SMBIOS_VERSION="${version}"
        '' + lib.optionalString (!isNull family) ''
          CONFIG_SYSINFO_SMBIOS_FAMILY="${family}"
        '') + lib.optionalString (!isNull ROCKCHIP_TPL) ''
          CONFIG_ROCKCHIP_EXTERNAL_TPL=y
        '' + lib.optionalString videoSupport ''
          CONFIG_VIDEO=y
          CONFIG_DISPLAY=y
        '' + lib.optionalString (!drmSupport) ''
          CONFIG_VIDEO_ROCKCHIP=y
          CONFIG_DISPLAY_ROCKCHIP_HDMI=y
        '' + lib.optionalString drmSupport ''
          CONFIG_DRM_ROCKCHIP_VIDEO_FRAMEBUFFER=y
          CONFIG_DRM_ROCKCHIP=y
          CONFIG_PHY_ROCKCHIP_SAMSUNG_HDPTX_HDMI=y
          CONFIG_DRM_ROCKCHIP_DW_HDMI_QP=y
        '' + lib.optionalString efiSupport ''
          CONFIG_BOOTSTD_FULL=y
          CONFIG_BOOTCOMMAND="bootmenu"
          CONFIG_BOOTMENU_DISABLE_UBOOT_CONSOLE=y
          CONFIG_CMD_BOOTMENU=y
          CONFIG_CMD_EFICONFIG=y
        '' + lib.optionalString preBootsupport ''
          CONFIG_USE_PREBOOT=y
          CONFIG_PREBOOT="${preBootcommand}"
        '' + lib.optionalString nvmeSupport ''
          CONFIG_PCI=y
          CONFIG_CMD_PCI=y
          CONFIG_NVME_PCI=y
          CONFIG_PCIE_DW_ROCKCHIP=y
        '' + lib.optionalString usbSupport ''
          CONFIG_PHY_ROCKCHIP_INNO_USB2=y
          CONFIG_PHY_ROCKCHIP_TYPEC=y
          CONFIG_PHY_ROCKCHIP_USBDP=y
          CONFIG_USB=y
          CONFIG_USB_XHCI_HCD=y
          CONFIG_USB_XHCI_DWC3=y
          CONFIG_USB_EHCI_HCD=y
          CONFIG_USB_EHCI_GENERIC=y
          CONFIG_USB_OHCI_HCD=y
          CONFIG_USB_OHCI_GENERIC=y
        '' + lib.optionalString keyboardSupport ''
          CONFIG_USB_KEYBOARD=y
          CONFIG_SYS_USB_EVENT_POLL_VIA_CONTROL_EP=y
        '' + extraConfig;

        extraMeta = {
          platforms = [ "aarch64-linux" ];
        };
        filesToInstall = [ "u-boot.itb" "idbloader.img" "u-boot-rockchip.bin" ];
      } // builtins.removeAttrs args [ "extraConfig" "extraPatches" ]));
in
{
  inherit ubootRockchip;
  ubootBozzSW799 = ubootRockchip {
    defconfig = "evb-rk3399_defconfig";
    deviceTree = "rockchip/rk3399-bozz-sw799a-5g";
    manufacturer = "Bozz";
    product = "Bozz SW799A";
    version = "5G";
    family = "Rockchip/RK3399";
    BL31 = "${armTrustedFirmwareRK3399}/bl31.elf";
    ROCKCHIP_TPL = "${rkbin}/bin/rk33/rk3399_ddr_800MHz_v1.30.bin";
  };

  ubootFine3399 = ubootRockchip {
    defconfig = "evb-rk3399_defconfig";
    deviceTree = "rockchip/rk3399-fine3399";
    manufacturer = "Bozz";
    product = "Fine3399";
    family = "Rockchip/RK3399";
    BL31 = "${armTrustedFirmwareRK3399}/bl31.elf";
    ROCKCHIP_TPL = "${rkbin}/bin/rk33/rk3399_ddr_800MHz_v1.30.bin";
  };

  ubootHinlinkH88k = ubootRockchip {
    defconfig = "evb-rk3588_defconfig";
    deviceTree = "rockchip/rk3588-hinlink-h88k";
    manufacturer = "HINLINK";
    product = "HINLINK H88K";
    family = "Rockchip/RK3588";
    drmSupport = true;
    BL31 = "${rkbin}/bin/rk35/rk3588_bl31_v1.45.elf";
    ROCKCHIP_TPL = rkbin.TPL_RK3588;
  };

  ubootRock5ModelB = ubootRockchip {
    defconfig = "rock5b-rk3588_defconfig";
    manufacturer = "Radxa";
    product = "Rock 5B";
    family = "Rockchip/RK3588";
    drmSupport = true;
    BL31 = "${rkbin}/bin/rk35/rk3588_bl31_v1.45.elf";
    ROCKCHIP_TPL = rkbin.TPL_RK3588;
  };
}

