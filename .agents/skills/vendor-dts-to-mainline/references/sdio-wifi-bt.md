# SDIO WiFi And UART Bluetooth Porting

Use this when translating vendor AMPAK/Broadcom combo module nodes into mainline RK3588 DTS.

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
