# GMAC And MDIO Porting

Use this when translating vendor GMAC, MDIO, RGMII PHY, reset, clock, and pinctrl data into mainline RK3588 DTS.

## RK3588 Checks

Compare these fields with vendor and known-good RK3588 boards:

```dts
&gmac1 {
	clock_in_out = "input";
	phy-mode = "rgmii";
	phy-handle = <&rgmii_phy1>;
	pinctrl-0 = <&gmac1_miim
		     &gmac1_tx_bus2
		     &gmac1_rx_bus2
		     &gmac1_rgmii_clk
		     &gmac1_rgmii_bus
		     &gmac1_clkinout>;
	snps,reset-gpio = <...>;
	snps,reset-active-low;
	snps,reset-delays-us = <0 20000 100000>;
};

&mdio1 {
	rgmii_phy1: ethernet-phy@1 {
		compatible = "ethernet-phy-ieee802.3-c22";
		reg = <1>;
	};
};
```

## Porting Order

1. Confirm the intended MAC instance and aliases.
2. Confirm MDIO address with vendor DTS/fdtdump.
3. Confirm reset property names match the running kernel.
4. Confirm `gmac*_clkinout` is present if vendor had it.
5. Confirm PHY power rails and pinctrl groups against vendor and known-good RK3588 boards.
