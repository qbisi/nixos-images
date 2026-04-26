---
name: vendor-dts-to-mainline
description: Use when converting or debugging Rockchip RK3588/RK3588S vendor DTS or fdtdump board files into mainline-style DTS in this repository. Covers fdtdump phandle decoding, translating vendor-only nodes to upstream bindings, Rockchip pinctrl conflicts, GMAC/MDIO, SDIO WiFi/Bluetooth, ES8388 audio, GPIO expanders, fixed regulators, and runtime boot-log triage on local or remote Linux boards.
---

# Vendor DTS To Mainline

Use this skill for RK3588/RK3588S board bring-up in this repo when the input is a vendor DTS, fdtdump, boot log, or a partially ported mainline DTS.

## Core Workflow

1. Compare three sources before editing:
   - target board: `dts/mainline/...`
   - vendor/fdtdump: `dts/vendor/...` and/or `dts/fdtdump/...`
   - known-good upstream or repo examples: `dts/mainline/rockchip/...`, `~/linux/arch/arm64/boot/dts/rockchip/...`
2. Treat fdtdump phandles as evidence. Decode phandles to controller labels before deciding GPIO bank, pin, and active level.
3. Translate vendor-specific nodes into upstream bindings; do not copy vendor `*-platdata` or `rockchip,*card` nodes blindly.
4. Let boot logs choose the layer to debug:
   - pinctrl conflict: wrong mux group or shared pins
   - probe missing device: reset/power/clock/address
   - firmware fallback: usually non-fatal until later feature failures
   - ALSA playback but silence: routing, DAPM, external amp GPIO
5. Keep changes scoped to the board and the smallest helper files needed. Do not reformat large DTS blocks.
6. If the user said not to validate, do not run DTS build/validation. Inspection, grep, and live runtime tests are fine.

## Rockchip Patterns

- Prefer nearby RK3588/RK3588S mainline examples over older SoCs.
- Vendor pinctrl mux numbers are useful, but mainline labels are safer when available.
- Always check inherited base DTSI pinctrl defaults. Example: RK3588 `&sdio` defaults to `sdiom1_pins`, which can conflict with GMAC1; a board may need `sdiom0_pins`.
- Model board power GPIOs as `regulator-fixed` or `simple-audio-amplifier` when they control supplies/amps, not as bare GPIOs.
- GPIO expanders should get `gpio-line-names` from vendor `gpio-leds`/misc nodes when those nodes were only being used as named GPIO holders.

## Subsystem References

Load only the relevant reference file:

- `references/fdtdump.md`: phandle/GPIO/pinctrl decoding workflow.
- `references/gmac-mdio.md`: stmmac reset, clkinout, MDIO missing PHY triage.
- `references/sdio-wifi-bt.md`: SDIO Broadcom/AMPAK WiFi plus UART Bluetooth porting.
- `references/es8388-audio.md`: ES8388 simple-audio-card, UCM, headphone amp GPIO, headless testing.
- `references/gpio-regulators-usb.md`: fixed regulators, expander line names, shared USB PHY vs downstream port power.

## Runtime Commands

Remote board access is often available through `ssh -F /dev/null root@10.0.10.1`. Use that form if local SSH config permissions break normal `ssh`.

Useful low-risk probes:

```sh
dmesg | grep -Ei 'pinctrl|mdio|stmmac|brcmfmac|Bluetooth|asoc|es83|i2s|mmc'
cat /proc/asound/cards
aplay -l
amixer -c 0 contents
gpioinfo
find /sys/kernel/debug/asoc -maxdepth 4 -type f
```

For playback testing without extra packages, generate a WAV with Perl and play it through the target card:

```sh
perl -e '$rate=48000;$sec=3;$freq=440;$amp=8000;$n=$rate*$sec;$data=$n*4;print pack("A4VA4A4VvvVVvvA4V","RIFF",36+$data,"WAVE","fmt ",16,1,2,$rate,$rate*4,4,16,"data",$data);for($i=0;$i<$n;$i++){ $s=int($amp*sin(2*3.141592653589793*$freq*$i/$rate)); print pack("ss",$s,$s); }' > /tmp/test.wav
aplay -D hw:0,0 /tmp/test.wav
```
