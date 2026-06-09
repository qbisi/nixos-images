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
    {
      defconfig,
      ...
    }@args:
    (pkgs.buildUBoot args).overrideAttrs (prev: {
      configurePhase = ''
        runHook preConfigure

        printf "%s" "$extraConfig" >> configs/${defconfig}

        make -j$NIX_BUILD_CORES ${defconfig}

        runHook postConfigure
      '';
    });

  buildUBootRk3399 =
    {
      dtsFile,
      patches ? [ ],
      extraConfig ? "",
      ...
    }@args:
    self.buildUBoot (
      {
        defconfig = "generic-rk3399_defconfig";
        env = {
          BL31 = "${pkgs.armTrustedFirmwareRK3399}/bl31.elf";
          ROCKCHIP_TPL = "${pkgs.rkbin}/bin/rk33/rk3399_ddr_800MHz_v1.30.bin";
        };
        filesToInstall = [
          "u-boot-rockchip.bin"
        ];
        prePatch = ''
          cp ${dtsFile} arch/arm/dts/${baseNameOf dtsFile}
        '';
        patches = [ ./patches/u-boot/spl-prefer-sdmmc.patch ] ++ patches;
        extraConfig = ''
          CONFIG_OF_UPSTREAM=n
          CONFIG_DEFAULT_DEVICE_TREE="${pkgs.lib.removeSuffix ".dts" (baseNameOf dtsFile)}"
          CONFIG_DEFAULT_FDT_FILE="rockchip/${pkgs.lib.removeSuffix ".dts" (baseNameOf dtsFile)}.dtb"
          CONFIG_VIDEO=y
          CONFIG_DISPLAY=y
          CONFIG_VIDEO_ROCKCHIP=y
          CONFIG_DISPLAY_ROCKCHIP_HDMI=y
          CONFIG_USE_PREBOOT=y
          CONFIG_PREBOOT="usb start;"
          CONFIG_PHY_ROCKCHIP_INNO_USB2=y
          CONFIG_PHY_ROCKCHIP_TYPEC=y
          CONFIG_USB=y
          CONFIG_USB_XHCI_HCD=y
          CONFIG_USB_EHCI_HCD=y
          CONFIG_USB_EHCI_GENERIC=y
          CONFIG_USB_OHCI_HCD=y
          CONFIG_USB_OHCI_GENERIC=y
          CONFIG_USB_DWC3=y
          CONFIG_USB_DWC3_GENERIC=y
          CONFIG_USB_KEYBOARD=y
          CONFIG_SYS_USB_EVENT_POLL_VIA_CONTROL_EP=y
        ''
        + extraConfig;
      }
      // removeAttrs args [
        "extraConfig"
        "patches"
      ]
    );

  buildUBootRk3588 =
    {
      dtsFile,
      patches ? [ ],
      extraConfig ? "",
      withMenu ? true,
      withLog ? false,
      withSpi ? false,
      withUsb ? withMenu,
      withNvme ? true,
      withDrm ? withMenu,
      withRecovery ? true,
      ...
    }@args:
    self.buildUBoot (
      {
        defconfig = "generic-rk3588_defconfig";
        env = {
          BL31 = "${pkgs.armTrustedFirmwareRK3588}/bl31.elf";
          ROCKCHIP_TPL = pkgs.rkbin.TPL_RK3588;
        };
        filesToInstall = [
          "u-boot-rockchip.bin"
        ]
        ++ pkgs.lib.optional withSpi "u-boot-rockchip-spi.bin";
        prePatch = ''
          cp ${dtsFile} arch/arm/dts/${baseNameOf dtsFile}
        '';
        patches = [
          ./patches/u-boot/spl-prefer-sdmmc.patch
          ./patches/u-boot/rk3588-adc-recovery.patch
          ./patches/u-boot/cmd-add-bootconfig.patch
          ./patches/u-boot/bootflow-menu-countdown.patch
          ./patches/u-boot/clk-enhance-clk-gpio-to-also-handle-gated-fixed-clock.patch
        ]
        ++ pkgs.lib.optional withDrm ./patches/u-boot/rockchip-video-drm.patch
        ++ patches;
        extraConfig = ''
          # disable smbios such that sound card can find profile in alsa-ucm-conf
          # see https://github.com/alsa-project/alsa-ucm-conf/pull/374
          CONFIG_SMBIOS=n
          CONFIG_OF_UPSTREAM=n
          CONFIG_ENV_IS_IN_MMC=y
          CONFIG_DEFAULT_DEVICE_TREE="${pkgs.lib.removeSuffix ".dts" (baseNameOf dtsFile)}"
          CONFIG_DEFAULT_FDT_FILE="rockchip/${pkgs.lib.removeSuffix ".dts" (baseNameOf dtsFile)}.dtb"
        ''
        + pkgs.lib.optionalString withMenu ''
          CONFIG_USE_PREBOOT=y
          CONFIG_PREBOOT="usb start; setenv boot_targets \"mmc1 nvme mmc0\""
          CONFIG_CMD_BOOTCONFIG=y
          CONFIG_EXPO=y
          CONFIG_BOOTDELAY=0
          CONFIG_BOOTCOMMAND="bootflow scan -mbG"
        ''
        + pkgs.lib.optionalString withLog ''
          CONFIG_LOG=y
          CONFIG_LOG_MAX_LEVEL=7
          CONFIG_LOG_DEFAULT_LEVEL=7
          CONFIG_SPL_LOG=y
          CONFIG_SPL_LOG_MAX_LEVEL=7
          CONFIG_SPL_LOG_CONSOLE=y
          CONFIG_LOGLEVEL=7
          CONFIG_SPL_LOGLEVEL=7
        ''
        + pkgs.lib.optionalString withSpi ''
          CONFIG_ENV_IS_IN_MMC=n
          CONFIG_ENV_IS_IN_SPI_FLASH=y
          CONFIG_ROCKCHIP_SFC=y
          CONFIG_ROCKCHIP_SPI_IMAGE=y
          CONFIG_SF_DEFAULT_SPEED=24000000
          CONFIG_SF_DEFAULT_MODE=0x2000
          CONFIG_SF_DEFAULT_BUS=5
          CONFIG_SPL_SPI_FLASH_SUPPORT=y
          CONFIG_SPL_SPI=y
          CONFIG_SPL_SPI_LOAD=y
          CONFIG_SYS_SPI_U_BOOT_OFFS=0x60000
          CONFIG_SPI_FLASH_SFDP_SUPPORT=y
          CONFIG_SPI_FLASH_MACRONIX=y
          CONFIG_SPI_FLASH_XMC=y
          CONFIG_SPI_FLASH_XTX=y
        ''
        + pkgs.lib.optionalString withRecovery ''
          CONFIG_ADC=y
          CONFIG_ROCKCHIP_SPI=y
          CONFIG_DM_PMIC=y
          CONFIG_PMIC_RK8XX=y
          CONFIG_REGULATOR_RK8XX=y
        ''
        + pkgs.lib.optionalString withNvme ''
          CONFIG_PCI=y
          CONFIG_CMD_PCI=y
          CONFIG_NVME_PCI=y
          CONFIG_PCIE_DW_ROCKCHIP=y
        ''
        + pkgs.lib.optionalString withUsb ''
          CONFIG_PHY_ROCKCHIP_NANENG_COMBOPHY=y
          CONFIG_PHY_ROCKCHIP_USBDP=y
          CONFIG_TYPEC_TCPM=y
          CONFIG_TYPEC_FUSB302=y
          CONFIG_CMD_USB=y
          CONFIG_USB=y
          CONFIG_USB_XHCI_HCD=y
          CONFIG_USB_EHCI_HCD=y
          CONFIG_USB_EHCI_GENERIC=y
          CONFIG_USB_OHCI_HCD=y
          CONFIG_USB_OHCI_GENERIC=y
          CONFIG_USB_DWC3=y
          CONFIG_USB_DWC3_GENERIC=y
          CONFIG_USB_KEYBOARD=y
          CONFIG_SYS_USB_EVENT_POLL_VIA_CONTROL_EP=y
        ''
        + pkgs.lib.optionalString withDrm ''
          CONFIG_VIDEO=y
          CONFIG_DISPLAY=y
          CONFIG_DRM_ROCKCHIP=y
          CONFIG_DRM_ROCKCHIP_VIDEO_FRAMEBUFFER=y
          CONFIG_DRM_ROCKCHIP_DW_HDMI_QP=y
          CONFIG_PHY_ROCKCHIP_SAMSUNG_HDPTX_HDMI=y
        ''
        + extraConfig;
      }
      // removeAttrs args [
        "extraConfig"
        "withUsb"
        "withNvme"
        "withRecovery"
        "withSpi"
        "withLog"
        "patches"
      ]
    );

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
      ...
    }@args:
    (pkgs.buildLinux args).override (prev: {
      defconfig = if isNull defconfigFile then prev.defconfig or null else "fromfile_defconfig";
      kernelPatches =
        prev.kernelPatches or [ ]
        ++ pkgs.lib.optional (!(isNull defconfigFile)) {
          name = "symlink-defconfigFile-to-kernel-defconfig";
          patch = self.makePatch {
            src = pkgs.emptyDirectory;
            patchCommands = ''
              mkdir -p arch/${kernalArch}/configs
              ln -s ${defconfigFile} arch/${kernalArch}/configs/fromfile_defconfig
            '';
          };
        };
    });
}
