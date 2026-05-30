# ES8388 Audio Bring-Up

Use this for RK3588 boards with ES8388/ES8328 codec, headphone jack, and silent playback.

## Mainline Model

Vendor may use `rockchip,multicodecs-card` with board-only properties:

```dts
hp-det-gpio = <&gpio1 RK_PC4 GPIO_ACTIVE_HIGH>;
hp-con-gpio = <&gpio1 RK_PD2 GPIO_ACTIVE_HIGH>;
spk-con-gpio = <...>;
rockchip,audio-routing = "Headphone", "LOUT1", ...
```

Mainline `simple-audio-card` needs amp/connect GPIOs modeled as `simple-audio-amplifier` aux devices:

```dts
analog-sound {
	compatible = "simple-audio-card";
	simple-audio-card,name = "rockchip,es8388";
	simple-audio-card,aux-devs = <&amp_headphone>;
	simple-audio-card,hp-det-gpios = <&gpio1 RK_PC4 GPIO_ACTIVE_HIGH>;
	simple-audio-card,pin-switches = "Headphones";
	simple-audio-card,routing =
		"Headphones Amplifier INL", "LOUT1",
		"Headphones Amplifier INR", "ROUT1",
		"Headphones", "Headphones Amplifier OUTL",
		"Headphones", "Headphones Amplifier OUTR";
};

amp_headphone: headphone-amplifier {
	compatible = "simple-audio-amplifier";
	enable-gpios = <&gpio1 RK_PD2 GPIO_ACTIVE_HIGH>;
	sound-name-prefix = "Headphones Amplifier";
};
```

Close RK3588 references:

- `rk3588-evb1-v10.dts`: ES8388 with headphone/speaker amplifiers.
- `rk3588-quartzpro64.dts`: headphone amp on GPIO1_D2.
- `rk3588-firefly-itx-3588j.dts`: simple-audio-amplifier plus routing.

## Runtime Debug

Check card and mixer state:

```sh
cat /proc/asound/cards
aplay -l
amixer -c rockchipes8388 contents
amixer -c rockchipes8388 cget name='Headphones Jack'
```

Apply UCM:

```sh
alsaucm -c hw:rockchipes8388 set _verb HiFi set _enadev Headphones
```

Generate and play a tone:

```sh
perl -e '$rate=48000;$sec=3;$freq=440;$amp=8000;$n=$rate*$sec;$data=$n*4;print pack("A4VA4A4VvvVVvvA4V","RIFF",36+$data,"WAVE","fmt ",16,1,2,$rate,$rate*4,4,16,"data",$data);for($i=0;$i<$n;$i++){ $s=int($amp*sin(2*3.141592653589793*$freq*$i/$rate)); print pack("ss",$s,$s); }' > /tmp/es8388-test.wav
aplay -D hw:rockchipes8388,0 /tmp/es8388-test.wav
```

Use DAPM to distinguish codec routing from external GPIO issues:

```sh
cat "/sys/kernel/debug/asoc/rockchip,es8388/dapm/Headphones"
cat "/sys/kernel/debug/asoc/rockchip,es8388/es8328.5-0011/dapm/LOUT1"
cat "/sys/kernel/debug/asoc/rockchip,es8388/es8328.5-0011/dapm/ROUT1"
```

If DAPM says `Headphones`, `LOUT1`, and `ROUT1` are on but there is silence, suspect an external amp/connect GPIO.

Manual GPIO test for V1A-style headphone connect:

```sh
gpioset -z -C hp-con-test -c gpiochip1 26=1
speaker-test -D hw:rockchipes8388,0 -c 2 -t sine -f 880
```

## Headless UCM

For headless boards, use a system service rather than relying on a desktop session:

```nix
systemd.services.es8388-headphones-ucm = {
  wantedBy = [ "multi-user.target" ];
  after = [ "sound.target" ];
  serviceConfig = {
    Type = "oneshot";
    RemainAfterExit = true;
    Environment = "ALSA_CONFIG_UCM2=${pkgs.alsa-ucm-conf-rk3588}/share/alsa/ucm2";
    ExecStart = "${pkgs.alsa-utils}/bin/alsaucm -c hw:rockchipes8388 set _verb HiFi set _enadev Headphones";
  };
};
```

`ALSA_CONFIG_UCM2` affects programs that use alsa-lib UCM and inherit the variable. Plain `aplay -D hw:...` does not apply UCM by itself.
