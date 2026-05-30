# GPIOs, Regulators, USB Power Porting

Use this for vendor GPIO holder nodes, PCA953x expanders, fixed regulators, and USB port power.

## GPIO Expanders

Vendor trees often use `gpio-leds` nodes to name GPIOs that are not actually LEDs. Map these into `gpio-line-names` on the expander.

Example pattern:

```dts
pca9539: gpio@74 {
	compatible = "nxp,pca9539";
	reg = <0x74>;
	gpio-controller;
	#gpio-cells = <2>;
	gpio-line-names =
		"", "", "fan", "usb_host3_pwr",
		"usb_host4_pwr", "host_J54", "host_J53", "",
		"usb_host1_pwr", "usb_host2_pwr", "host_J52", "host_J55",
		"", "", "edp_on", "";
};
```

## Fixed Regulators

Use fixed regulators for board power switches that should be enabled by Linux:

```dts
vcc5v0_usb_host3: regulator-vcc5v0-usb-host3 {
	compatible = "regulator-fixed";
	regulator-name = "vcc5v0_usb_host3";
	regulator-boot-on;
	regulator-always-on;
	regulator-min-microvolt = <5000000>;
	regulator-max-microvolt = <5000000>;
	gpio = <&pca9539 3 GPIO_ACTIVE_HIGH>;
	enable-active-high;
	vin-supply = <&vcc5v0_host>;
};
```

If the user needs manual userspace control, do not bind that GPIO to a regulator because the regulator framework owns the line.

## USB Hub And Shared PHY

When one RK3588 PHY/controller feeds an external USB hub, and multiple downstream USB ports have independent VBUS switches:

- Do not attach two downstream VBUS regulators as one `phy-supply`.
- Model downstream port power as always-on fixed regulators if the ports should simply be powered.
- Keep names explicit (`usb_host3_pwr`, `usb_host4_pwr`) using regulator names or `gpio-line-names`.
