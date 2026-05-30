---
name: vendor-dts-to-mainline
description: Use when converting Rockchip RK3588/RK3588S vendor DTS or fdtdump board files into mainline-style DTS in this repository. Covers fdtdump phandle decoding, translating vendor-only nodes to upstream bindings, Rockchip pinctrl selection, GMAC/MDIO, SDIO WiFi/Bluetooth, ES8388 audio, GPIO expanders, and fixed regulators.
---

# Vendor DTS To Mainline

Use this skill for RK3588/RK3588S board bring-up in this repo when the input is a vendor DTS, fdtdump, or a partially ported mainline DTS.

## Core Workflow

1. Compare three sources before editing:
   - target board: `dts/mainline/...`
   - vendor/fdtdump: `dts/vendor/...` and/or `dts/fdtdump/...`
   - known-good upstream or repo examples: `dts/mainline/rockchip/...`, `~/linux/arch/arm64/boot/dts/rockchip/...`
2. Treat fdtdump phandles as evidence. Decode phandles to controller labels before deciding GPIO bank, pin, and active level.
3. Translate vendor-specific nodes into upstream bindings; do not copy vendor `*-platdata` or `rockchip,*card` nodes blindly.
4. Keep changes scoped to the board and the smallest helper files needed. Do not reformat large DTS blocks.

## Rockchip Patterns

- Prefer nearby RK3588/RK3588S mainline examples over older SoCs.
- Vendor pinctrl mux numbers are useful, but mainline labels are safer when available.
- Always check inherited base DTSI pinctrl defaults. Example: RK3588 `&sdio` defaults to `sdiom1_pins`, which can conflict with GMAC1; a board may need `sdiom0_pins`.
- Model board power GPIOs as `regulator-fixed` or `simple-audio-amplifier` when they control supplies/amps, not as bare GPIOs.
- GPIO expanders should get `gpio-line-names` from vendor `gpio-leds`/misc nodes when those nodes were only being used as named GPIO holders.

## Subsystem References

Load only the relevant reference file:

- `references/fdtdump.md`: phandle/GPIO/pinctrl decoding workflow.
- `references/gmac-mdio.md`: stmmac reset, clkinout, MDIO bus, and RGMII PHY modeling.
- `references/sdio-wifi-bt.md`: SDIO Broadcom/AMPAK WiFi plus UART Bluetooth porting.
- `references/es8388-audio.md`: ES8388 simple-audio-card, routing, headphone jack, and amp GPIO modeling.
- `references/gpio-regulators-usb.md`: fixed regulators, expander line names, shared USB PHY vs downstream port power.
