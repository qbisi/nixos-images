---
name: vendor-dts-to-mainline
description: Use when converting vendored Rockchip RK3588 or RK3588S DTS files in this repository into cleaned mainline-style working DTS files. Covers importing repo-local DTS and dt-binding references, preserving protected local boards, treating .dts.dumped files as read-only dump inputs, and running the RK3588 dump cleaner plus validation workflow.
---

# Vendor DTS To Mainline

Use this skill when working on RK3588 or RK3588S DTS cleanup in this repo.

## Scope

- `rk3588` and `rk3588s` only
- repo-local references live under `dts/vendor/` and `dts/mainline/`
- focus on board-varying function nodes such as UART, SPI, I2C, PMIC, GMAC, USB, PCIe, HDMI, and sound

## Reference import

Refresh local references with:

```bash
python3 tools/dts/import_rk3588_references.py
```

This copies:

- vendor RK3588 DTS and DTSI files from `~/linux-rockchip` into `dts/vendor/`
- mainline RK3588 DTS and DTSI files from `~/linux` into `dts/mainline/`
- required `dt-bindings` headers into both trees

Protected local vendor files are preserved:

- `dts/vendor/rk3588-hinlink-h88k.dts`
- `dts/vendor/rk3588-jwipc-e88a.dts`
- `dts/vendor/rk3588-jwipc-e88a.dts.dumped`

`dts/vendor/rk3588-friendlyelec-cm3588-nas.dts` may be refreshed from source.

## Dumped versus cleaned files

For boards under active cleanup:

- `.dts.dumped` is the preserved dumped input
- `.dts` is the cleaned working output

Current board convention:

- `dts/vendor/rk3588-jwipc-e88a.dts.dumped` is the original dump
- `dts/vendor/rk3588-jwipc-e88a.dts` is the cleaned output

Treat `.dts.dumped` files as read-only input.

## Cleanup workflow

Run the cleaner with:

```bash
python3 tools/dts/clean_rk3588_dump.py dts/vendor/rk3588-jwipc-e88a.dts.dumped
```

The cleaner:

- detects `rk3588` vs `rk3588s`
- otherwise emits a conservative skeleton around the SoC `.dtsi`
- prints a summary to stdout
- validates with `cpp` plus `dtc` when both tools are installed

## Validation

When `cpp` and `dtc` are available, validate output against repo-local include roots:

```bash
python3 tools/dts/clean_rk3588_dump.py dts/vendor/rk3588-jwipc-e88a.dts.dumped
```

Read the cleaner stdout for unresolved nodes and validation errors.

## Rules of thumb

- preserve board facts, not vendor dump structure
- never guess low-confidence phandle or pin conversions
- keep unresolved nodes present and report them instead of deleting them silently
- use cleaned DTS files only as human references when improving the hardcoded scripts, not as runtime inputs to the scripts
