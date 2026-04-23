# Rockchip USB loader blobs

This directory keeps Rockchip loader binaries used by `rkdeveloptool` or
Rockchip `upgrade_tool` when a board is in MaskROM mode. These files are not
compiled from source in this repository. They are packed by Rockchip's
`rkbin/tools/boot_merger` from prebuilt DDR, USB plug, and miniloader/SPL
firmware blobs in `rkbin`.

Current files:

| File | SHA256 |
| --- | --- |
| `rk3399_loader_v1.30.130.bin` | `9c2a6fc65279a30e3b0a2640f6c5becd69b42e78579d21852753504fc5afca08` |
| `rk3588_spl_loader_v1.19.113.bin` | `5028af1b343942121cb7782339f35bb18307d71e99a201a0399b05888a800651` |

## Generate from rkbin

Use the Rockchip `rkbin` repository:

```sh
git clone https://github.com/rockchip-linux/rkbin.git
cd rkbin
```

Then run `boot_merger` with the SoC-specific `RKBOOT` config:

```sh
./tools/boot_merger RKBOOT/RK3399MINIALL.ini
./tools/boot_merger RKBOOT/RK3588MINIALL.ini
```

The resulting binaries are written in the current `rkbin` directory:

```text
rk3399_loader_v1.30.130.bin
rk3588_spl_loader_v1.19.113.bin
```

Copy those outputs into this repository's `tools/` directory.

Note: `boot_merger` is a Rockchip-provided host binary. If it cannot run on the
current machine, run the command in a compatible Linux environment or use the
matching `rkbin` tool for that host.

## Usage

Put the board in MaskROM mode, confirm the USB device is visible, then download
the loader:

```sh
rkdeveloptool ld
rkdeveloptool db tools/rk3588_spl_loader_v1.19.113.bin
```

For RK3399 boards, use:

```sh
rkdeveloptool db tools/rk3399_loader_v1.30.130.bin
```

After the loader is accepted, `rkdeveloptool` can access the board's flash. For
example:

```sh
rkdeveloptool read-flash-info
rkdeveloptool wl 0 image.img
rkdeveloptool rd
```

These loader blobs are temporary USB-side helpers for recovery and flashing.
They are separate from the normal boot artifacts built by U-Boot, such as
`idbloader.img`, `u-boot.itb`, and `u-boot-rockchip.bin`.
