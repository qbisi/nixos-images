# DTS Tree Layout

This directory keeps three kinds of device-tree sources:

- `dts/mainline/`: DTS files and includes based on upstream Linux.
- `dts/vendor/`: DTS files and includes based on the Rockchip vendor tree.
- `dts/fdtdump/`: raw DTS files dumped from a running kernel for reference.

## `dts/mainline/`

Mainline files are copied from Linux kernel `6.18` and then adjusted out of tree for boards that are not upstream yet.

Upstream reference:

- kernel source: <https://github.com/torvalds/linux/tree/v6.18>

Layout:

- `dts/mainline/dt-bindings/`: copied from `include/dt-bindings/` in upstream Linux.
- `dts/mainline/rockchip/`: copied from `arch/arm64/boot/dts/rockchip/` in upstream Linux.
- `dts/mainline/*.dts`: local out-of-tree board entry points in this repo.

## `dts/vendor/`

Vendor files are copied from Armbian's `linux-rockchip` kernel tree and then adjusted locally when needed.

Reference used by this repo:

- source repo: <https://github.com/armbian/linux-rockchip>

Layout:

- `dts/vendor/dt-bindings/`: copied from the vendor kernel's dt-binding headers.
- `dts/vendor/rockchip/`: copied from the vendor kernel's Rockchip DTS subtree.
- `dts/vendor/*.dts`: local out-of-tree board entry points in this repo.

## `dts/fdtdump/`

`fdtdump/` keeps raw DTS output dumped from a running system. These files are inputs and references, not cleaned hand-maintained DTS files.

Example command:

```sh
dtc -I dtb -O dts /sys/firmware/fdt > board.dts
```

Current dumped files:

- `rk3588-ido-evb3588-v1a.dts`
- `rk3588-jwipc-e88a.dts`

## Workflow

to be implemented when instructed explicitly
