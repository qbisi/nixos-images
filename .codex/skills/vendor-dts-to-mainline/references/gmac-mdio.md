# GMAC And MDIO

Use this when boot logs mention stmmac, MDIO, missing PHYs, or Ethernet pin/reset problems.

## Log Meanings

`MDIO device at address 1 is missing.`

The kernel attempted to read/register the PHY at MDIO address 1 and got no valid response. Likely causes:

- PHY reset GPIO not asserted/deasserted correctly.
- Wrong stmmac reset property names for the kernel binding in use.
- Missing PHY clock or `gmac*_clkinout` pin.
- Wrong `phy-mode`, MDIO address, or MAC instance.
- Pinctrl conflict or missing MIIM pins.
- PHY power rail disabled.

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

## Kernel Source Anchors

When source is available in `~/linux`:

- `drivers/net/mdio/of_mdio.c`: logs missing MDIO devices.
- `drivers/net/mdio/fwnode_mdio.c`: reads generic PHY IDs.
- `drivers/net/ethernet/stmicro/stmmac/stmmac_mdio.c`: stmmac MDIO/reset handling.

## Triage Order

1. Confirm the intended MAC instance and aliases.
2. Confirm MDIO address with vendor DTS/fdtdump.
3. Confirm reset property names match the running kernel.
4. Confirm `gmac*_clkinout` is present if vendor had it.
5. Confirm power rails and pinctrl ownership in boot logs.
