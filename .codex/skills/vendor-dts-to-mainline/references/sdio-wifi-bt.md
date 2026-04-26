# SDIO WiFi And UART Bluetooth

Use this for AMPAK/Broadcom combo modules on RK3588 boards.

## Vendor To Mainline Translation

Do not port these vendor nodes directly:

```dts
wireless-wlan { compatible = "wlan-platdata"; wifi_chip_type = "..."; };
wireless-bluetooth { compatible = "bluetooth-platdata"; ... };
```

Translate to:

- `mmc-pwrseq-simple` for WiFi reset/enable and optional 32 kHz clock.
- `&sdio` child `wifi@1` for Broadcom fullmac SDIO.
- UART child `bluetooth` for Broadcom HCI UART.

## SDIO Pattern

```dts
sdio_pwrseq: sdio-pwrseq {
	compatible = "mmc-pwrseq-simple";
	clocks = <&hym8563>;
	clock-names = "ext_clock";
	reset-gpios = <&gpio0 RK_PC7 GPIO_ACTIVE_LOW>;
	post-power-on-delay-ms = <200>;
};

&sdio {
	#address-cells = <1>;
	#size-cells = <0>;
	bus-width = <4>;
	cap-sdio-irq;
	keep-power-in-suspend;
	mmc-pwrseq = <&sdio_pwrseq>;
	no-mmc;
	no-sd;
	non-removable;
	pinctrl-names = "default";
	pinctrl-0 = <&sdiom0_pins>; /* verify against fdtdump */
	sd-uhs-sdr104;
	status = "okay";

	wifi@1 {
		compatible = "brcm,bcm43752-fmac", "brcm,bcm4329-fmac";
		reg = <1>;
		interrupt-parent = <&gpio4>;
		interrupts = <RK_PC6 IRQ_TYPE_LEVEL_HIGH>;
		interrupt-names = "host-wake";
		brcm,board-type = "rockchip,board-name";
	};
};
```

Keep the `brcm,bcm4329-fmac` fallback for SDIO Broadcom nodes because brcmfmac OF setup uses it to parse SDIO OOB IRQ details.

## Bluetooth Pattern

```dts
&uart9 {
	pinctrl-0 = <&uart9m0_xfer &uart9m0_ctsn &uart9m0_rtsn>;
	uart-has-rtscts;
	status = "okay";

	bluetooth {
		compatible = "brcm,bcm4345c5";
		clocks = <&hym8563>;
		clock-names = "lpo";
		shutdown-gpios = <&gpio0 RK_PC6 GPIO_ACTIVE_HIGH>;
		device-wakeup-gpios = <&gpio2 RK_PC1 GPIO_ACTIVE_HIGH>;
		interrupt-parent = <&gpio2>;
		interrupts = <RK_PB6 IRQ_TYPE_LEVEL_HIGH>;
		interrupt-names = "host-wakeup";
		max-speed = <1500000>;
	};
};
```

## Boot Log Interpretation

- `pin gpioX-Y already requested ... cannot claim for fe2d0000.mmc`: wrong SDIO pinctrl group or pin shared with another enabled controller.
- `using brcm/brcmfmac43752-sdio for chip BCM43752/2`: SDIO transport and chip probe work.
- Missing board-specific `brcmfmac*.board.bin` or `.txt` with `error -2`: file not found; often non-fatal if generic firmware loads.
- `no txcap_blob available`: expected for SDIO in many kernels; txcap is mainly wired for PCIe.
- `brcmf_p2p_create_p2pdev timeout`: WiFi Direct/P2P failed, not normal station mode. Disable P2P in wpa_supplicant if not needed:
  ```nix
  networking.wireless.extraConfig = ''
    p2p_disabled=1
  '';
  ```
