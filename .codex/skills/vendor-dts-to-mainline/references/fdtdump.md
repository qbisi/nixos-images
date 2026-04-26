# Fdtdump Decoding

Use fdtdump as a map from opaque numeric phandles to real controllers and pins.

## Phandle Workflow

1. Find the consumer property:
   ```sh
   rg -n 'hp-con-gpio|reset-gpios|pinctrl-0|mmc-pwrseq|host_wake|phandle = <0x...>' dts/fdtdump/BOARD.dts
   ```
2. Search for each phandle:
   ```sh
   rg -n 'phandle = <0x16d>|phandle = <0x1ba>' dts/fdtdump/BOARD.dts
   ```
3. Decode GPIO specifiers:
   - `<&gpio1 0x1a 0x00>` means GPIO bank 1, line 26, active high.
   - RK pin names are `line = bank_letter * 8 + index`; line 26 is `RK_PD2`.
   - The last cell is usually GPIO flags: `0` active high, `1` active low in many dumped vendor trees; verify with binding/include context.
4. Decode pinctrl tuples:
   - `rockchip,pins = <bank line mux config ...>`
   - Replace hex bank/line/mux with `RK_P*` and `RK_FUNC_GPIO` where possible.

## What To Trust

- Trust fdtdump for actual active node state, GPIOs, pin muxes, and phandle topology.
- Prefer source vendor DTS labels when available; fdtdump loses labels and comments.
- If source and fdtdump disagree, fdtdump tells what firmware actually booted with.

## Common Mistakes

- Letting a node inherit a base DTSI pinctrl group without checking vendor fdtdump.
- Copying fdtdump hex config values like `0x177` instead of mainline `&pcfg_pull_none` labels when labels exist.
- Assuming vendor `gpio-leds` nodes are LEDs; on Rockchip vendor trees they are often named GPIO holders.
