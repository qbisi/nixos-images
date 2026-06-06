---
name: rk3588-runtime-debug
description: Use when debugging live Rockchip RK3588/RK3588S board bring-up problems from boot logs, dmesg, sysfs/debugfs, SSH probes, or runtime symptoms such as pinctrl conflicts, missing MDIO PHYs, SDIO WiFi/Bluetooth failures, ALSA/ASoC audio failures, GPIO/regulator ownership, or USB power issues.
---

# RK3588 Runtime Debug

Use this skill for live-board triage after a mainline or NixOS image boots far enough to collect logs or run commands. Prefer evidence from the running kernel before changing DTS or NixOS config.

## Core Workflow

1. Identify the failing subsystem from symptoms and logs:
   - pinctrl conflict: wrong mux group, shared pins, inherited base DTSI default
   - probe missing device: reset, power, clock, bus address, or disabled parent
   - firmware fallback: usually non-fatal unless the feature later fails
   - audio card present but silent: mixer, UCM, DAPM route, endpoint, external amp, mux, or jack/connect GPIO
2. Collect narrow logs first:
   ```sh
   dmesg | grep -Ei 'pinctrl|mdio|stmmac|brcmfmac|Bluetooth|asoc|snd|codec|i2s|mmc|regulator|gpio|usb|xhci|ehci|hub'
   ```
3. Compare runtime evidence with DTS only after the failing device, line, address, or clock is known.
4. Use one manual probe at a time. Record what changed and avoid leaving GPIOs exported or held by test commands.
5. If a change must be validated on a host, follow repo/AGENTS guidance for Colmena rather than ad hoc deployment.

## Remote Access

Remote board access is often available through:

```sh
ssh -F /dev/null root@10.0.10.1
```

Use `-F /dev/null` when local SSH config permissions or host aliases interfere.

## Reference Selection

Load only the relevant reference:

- `references/audio-runtime.md`: ALSA/ASoC card detection, mixer/UCM, DAPM, silent playback, codec and amp GPIO triage.
- `references/gmac-mdio-runtime.md`: stmmac, MDIO, missing PHY, RGMII reset/clock/pinctrl triage.
