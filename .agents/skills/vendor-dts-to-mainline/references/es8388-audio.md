# ES8388 Audio Porting

Use this when translating vendor ES8388/ES8328 audio-card, headphone jack, and amplifier GPIO data into mainline RK3588 DTS.

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
