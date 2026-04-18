from __future__ import annotations

from .parse import has_property, property_value


def classify_block(block: str) -> str:
    compatible = property_value(block, "compatible") or ""
    lowered = compatible.lower()
    if "regulator-fixed" in lowered or "regulator-gpio" in lowered:
        return "regulator"
    if "gpio-leds" in lowered:
        return "leds"
    if "gpio-keys" in lowered:
        return "keys"
    if "pwm-fan" in lowered:
        return "fan"
    if "mmc-pwrseq" in lowered:
        return "mmc-pwrseq"
    if "hdmi-connector" in lowered or "simple-panel" in lowered or "edp-panel" in lowered:
        return "display"
    if "audio-graph-card" in lowered or "simple-audio-card" in lowered or "rockchip,hdmi" in lowered:
        return "audio"
    if "bluetooth" in lowered or "wlan" in lowered or "rfkill-gpio" in lowered:
        return "wireless"
    if "rtc@" in block.lower():
        return "rtc"
    if has_property(block, "status") and property_value(block, "status") == '"okay"':
        return "enabled-node"
    return "generic"

