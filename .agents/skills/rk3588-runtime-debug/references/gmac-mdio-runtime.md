# GMAC And MDIO Runtime Debug

Use this when boot logs mention `stmmac`, `mdio`, missing PHYs, Ethernet reset, RGMII, or MAC pinctrl failures.

## Log Meanings

`MDIO device at address 1 is missing.`

The kernel tried to read/register the PHY at MDIO address 1 and got no valid response. Likely causes:

- PHY reset GPIO not asserted/deasserted correctly.
- Reset property names do not match the running stmmac binding.
- PHY clock or `gmac*_clkinout` pin is missing.
- Wrong `phy-mode`, MDIO address, or MAC instance.
- Pinctrl conflict or missing MIIM/RGMII pins.
- PHY power rail is disabled.

## Probes

```sh
dmesg | grep -Ei 'stmmac|mdio|ethernet|rgmii|pinctrl|reset|phy'
ip link
ethtool eth0
cat /sys/kernel/debug/gpio
```

If source is available in `~/linux`, check log sites and binding behavior:

- `drivers/net/mdio/of_mdio.c`
- `drivers/net/mdio/fwnode_mdio.c`
- `drivers/net/ethernet/stmicro/stmmac/stmmac_mdio.c`

## Triage Order

1. Confirm the intended MAC instance and aliases.
2. Confirm MDIO address against vendor DTS/fdtdump or board schematic.
3. Confirm reset property names and polarity for the running kernel.
4. Confirm `gmac*_clkinout` is present if vendor used it.
5. Confirm PHY power rails and pinctrl ownership in boot logs.
