# Audio Runtime Debug

Use this for RK3588 ALSA/ASoC audio failures: missing sound cards, wrong playback or capture devices, silent output, missing routes, bad mixer state, UCM problems, DAPM routing, codec probe issues, and external amplifier or connector GPIOs. Do not assume the codec is ES8388.

## Core Workflow

1. Identify the failure layer:
   - no card: codec, CPU DAI, clock, reset, bus, driver, or DTS binding
   - card present but no device: DAI link, PCM registration, or disabled endpoint
   - wrong device: card/device selection or default ALSA/Pulse/PipeWire routing
   - silent playback: mixer, UCM, DAPM route, endpoint, external amp, mux, or jack/connect GPIO
   - capture failure: input mux, bias, ADC path, mic bias, channel map, or sample format
2. Collect card and kernel evidence before changing mixer state:
   ```sh
   cat /proc/asound/cards
   aplay -l
   arecord -l
   dmesg | grep -Ei 'asoc|snd|codec|i2s|i2c|dma|jack|audio'
   ```
3. Avoid assuming card `0` when multiple cards exist. Use the stable card name from `/proc/asound/cards` or `aplay -l`.
4. Test one path at a time: direct ALSA `hw:` first, then UCM, then higher-level sound servers.
5. Before toggling GPIOs manually, confirm ownership with `gpioinfo` or `/sys/kernel/debug/gpio`.

## Mixer And UCM

Dump mixer state for the target card:

```sh
amixer -c CARD contents
amixer -c CARD scontents
```

If the board has UCM profiles, apply the intended verb and device before judging routing:

```sh
alsaucm -c hw:CARD set _verb HiFi
alsaucm -c hw:CARD list _devices
alsaucm -c hw:CARD set _verb HiFi set _enadev DEVICE
```

`ALSA_CONFIG_UCM2` affects programs that use alsa-lib UCM and inherit the variable. Plain `aplay -D hw:...` does not apply UCM by itself.

## Playback And Capture Tests

For playback testing without extra packages, generate a WAV with Perl:

```sh
perl -e '$rate=48000;$sec=3;$freq=440;$amp=8000;$n=$rate*$sec;$data=$n*4;print pack("A4VA4A4VvvVVvvA4V","RIFF",36+$data,"WAVE","fmt ",16,1,2,$rate,$rate*4,4,16,"data",$data);for($i=0;$i<$n;$i++){ $s=int($amp*sin(2*3.141592653589793*$freq*$i/$rate)); print pack("ss",$s,$s); }' > /tmp/test.wav
aplay -D hw:CARD,DEVICE /tmp/test.wav
```

For capture:

```sh
arecord -D hw:CARD,DEVICE -f S16_LE -r 48000 -c 2 -d 5 /tmp/capture.wav
aplay /tmp/capture.wav
```

## DAPM And Routing

Use DAPM to distinguish codec routing from external GPIO or endpoint issues:

```sh
find /sys/kernel/debug/asoc -maxdepth 4 -type f | sort
cat /sys/kernel/debug/asoc/CARD/dapm/WIDGET
cat /sys/kernel/debug/asoc/CARD/CODEC/dapm/WIDGET
```

If the relevant CPU DAI, codec output widgets, and endpoint widgets are on but there is silence, suspect an external amp, mux, jack/connect GPIO, or wrong physical output.

## GPIO And External Amps

Check ownership before manual tests:

```sh
gpioinfo
cat /sys/kernel/debug/gpio
```

Use manual GPIO tests only when the line is not already owned by a kernel driver and the board wiring is understood:

```sh
gpioset -z -C audio-test -c gpiochipN LINE=1
speaker-test -D hw:CARD,DEVICE -c 2 -t sine -f 880
```

## ES8388/ES8328 Example

For common Rockchip ES8388 cards:

```sh
amixer -c rockchipes8388 contents
amixer -c rockchipes8388 cget name='Headphones Jack'
alsaucm -c hw:rockchipes8388 set _verb HiFi set _enadev Headphones
aplay -D hw:rockchipes8388,0 /tmp/test.wav
```

Useful DAPM widgets often include:

```sh
cat "/sys/kernel/debug/asoc/rockchip,es8388/dapm/Headphones"
cat "/sys/kernel/debug/asoc/rockchip,es8388/es8328.5-0011/dapm/LOUT1"
cat "/sys/kernel/debug/asoc/rockchip,es8388/es8328.5-0011/dapm/ROUT1"
```
