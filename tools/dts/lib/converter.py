from __future__ import annotations

from pathlib import Path
import re

from .board_model import BoardModel, NodeFact, OverlayFact, UnresolvedFact
from .classify import classify_block
from .parse import (
    detect_soc_family,
    extract_block,
    extract_block_from_index,
    find_compatible_list,
    find_includes,
    find_model,
    has_property,
    iter_overlay_blocks,
    iter_root_blocks,
    parse_aliases,
    property_value,
)
from .render import render_board_model


SINGLE_RK806_REQUIRED_NAMES = (
    "vdd_gpu_s0",
    "vdd_cpu_lit_s0",
    "vdd_log_s0",
    "vdd_vdenc_s0",
    "vdd_ddr_s0",
    "vdd2_ddr_s3",
    "vcc_1v8_s0",
    "vdd_0v85_s0",
)
LABEL_REF_RE = re.compile(r"<&([\w]+)")
ANGLE_VALUE_RE = re.compile(r"<([^>]+)>")
WHOLE_LIST_PHANDLE_PROPERTIES = {"pinctrl-0", "pinctrl-1", "pinctrl-2"}
FIRST_TOKEN_PHANDLE_PROPERTIES = {
    "WIFI,host_wake_irq",
    "clocks",
    "connect",
    "enable-gpios",
    "gpio",
    "gpios",
    "hdmirx-det-gpios",
    "host-wakeup-gpios",
    "hp-det-gpio",
    "interrupt-parent",
    "io-channels",
    "mmc-pwrseq",
    "pwms",
    "remote-endpoint",
    "reset-gpios",
    "rockchip,bitclock-master",
    "rockchip,codec",
    "rockchip,cpu",
    "rockchip,frame-master",
    "sbu1-dc-gpios",
    "sbu2-dc-gpios",
    "vbat-supply",
    "vbus-supply",
    "vin-supply",
    "vmmc-supply",
    "vpcie3v3-supply",
    "vqmmc-supply",
    "vref-supply",
}
ROOT_NODE_LABELS = {
    "bt-wake-gpio-regulator": "bt_wake",
    "dp0-sound": "dp0_sound",
    "es8316-sound": "es8316_sound",
    "hdmi0-sound": "hdmi0_sound",
    "hdmi1-sound": "hdmi1_sound",
    "pwm-fan": "fan0",
    "sdio-pwrseq": "sdio_pwrseq",
    "vcc-1v1-nldo-s3": "vcc_1v1_nldo_s3",
    "vcc12v-dcin": "vcc12v_dcin",
    "vcc3v3-pcie2x1l0": "vcc3v3_pcie2x1l0",
    "vcc3v3-pcie2x1l2": "vcc3v3_pcie2x1l2",
    "vcc3v3-pcie30": "vcc3v3_pcie30",
    "vcc5v0-host-regulator": "vcc5v0_host",
    "vcc5v0-sys": "vcc5v0_sys",
    "vcc5v0-usb": "vcc5v0_usb",
    "vcc5v0-usbdcin": "vcc5v0_usbdcin",
    "wifi-diable-gpio-regulator": "wifi_disable",
    "wireless-wlan": "wireless_wlan",
}
KNOWN_PHANDLE_LABELS = {
    "dp@fde50000": "dp0",
    "es8316@11": "es8316",
    "gpio@fd8a0000": "gpio0",
    "gpio@fec20000": "gpio1",
    "gpio@fec30000": "gpio2",
    "gpio@fec40000": "gpio3",
    "gpio@fec50000": "gpio4",
    "hdmi@fde80000": "hdmi0",
    "hdmi@fdea0000": "hdmi1",
    "hym8563@51": "hym8563",
    "i2s@fddf0000": "i2s5_8ch",
    "i2s@fddf4000": "i2s6_8ch",
    "i2s@fe470000": "i2s0_8ch",
    "pwm@fd8b0010": "pwm1",
    "saradc@fec10000": "saradc",
    "sdio-pwrseq": "sdio_pwrseq",
    "spdif-tx@fddb0000": "spdif_tx2",
    "vcc-1v1-nldo-s3": "vcc_1v1_nldo_s3",
    "vcc12v-dcin": "vcc12v_dcin",
    "vcc5v0-host-regulator": "vcc5v0_host",
    "vcc5v0-sys": "vcc5v0_sys",
    "wifi-enable-h": "wifi_enable_h",
    "wifi-host-wake-irq": "wifi_host_wake_irq",
    "hp-det": "hp_det",
    "vcc5v0-host-en": "vcc5v0_host_en",
}
IMPORTED_NODE_TARGETS = {
    "hdmi@fde80000": "hdmi0",
    "hdmi@fdea0000": "hdmi1",
    "mmc@fe2c0000": "sdmmc",
    "mmc@fe2d0000": "sdio",
    "mmc@fe2e0000": "sdhci",
    "pcie@fe150000": "pcie3x4",
    "pcie@fe160000": "pcie3x2",
    "pcie@fe170000": "pcie2x1l0",
    "pcie@fe180000": "pcie2x1l1",
    "pcie@fe190000": "pcie2x1l2",
    "phy@fee80000": "pcie30phy",
    "usb@fc800000": "usb_host0_ehci",
    "usb@fc840000": "usb_host0_ohci",
    "usb@fc880000": "usb_host1_ehci",
    "usb@fc8c0000": "usb_host1_ohci",
    "usb@fc000000": "usbdrd_dwc3_0",
    "usb@fc400000": "usbdrd_dwc3_1",
    "usb@fcd00000": "usbhost_dwc3_0",
    "usbdrd3_0": "usbdrd3_0",
    "usbdrd3_1": "usbdrd3_1",
    "usbhost3_0": "usbhost3_0",
    "phy@fed80000": "usbdp_phy0",
    "phy@fed90000": "usbdp_phy1",
}
IMPORTED_NODE_ORDER = (
    "hdmi@fde80000",
    "hdmi@fdea0000",
    "mmc@fe2c0000",
    "mmc@fe2d0000",
    "mmc@fe2e0000",
    "pcie@fe150000",
    "pcie@fe160000",
    "pcie@fe170000",
    "pcie@fe180000",
    "pcie@fe190000",
    "phy@fee80000",
    "usb@fc800000",
    "usb@fc840000",
    "usb@fc880000",
    "usb@fc8c0000",
    "usbdrd3_0",
    "usb@fc000000",
    "usbdrd3_1",
    "usb@fc400000",
    "usbhost3_0",
    "usb@fcd00000",
    "phy@fed80000",
    "phy@fed90000",
)
ALIASES_PATH_RE = re.compile(r'^\s*([\w\-]+)\s*=\s*"([^"]+)";', re.MULTILINE)
ALIAS_TARGET_RENAMES = {
    "hdptxhdmi0": "hdptxphy_hdmi0",
    "hdptxhdmi1": "hdptxphy_hdmi1",
    "hdmirx0": "hdmirx_ctrler",
    "mmc0": "sdhci",
    "mmc1": "sdmmc",
    "mmc2": "sdio",
    "usbdp0": "usbdp_phy0",
    "usbdp1": "usbdp_phy1",
}
ROOT_NODE_TARGETS = {
    "display-subsystem": "display_subsystem",
    "hdmiphy@fed60000": "hdptxphy_hdmi0",
    "hdmiphy@fed70000": "hdptxphy_hdmi1",
    "jpege-ccu": "jpege_ccu",
    "mpp-srv": "mpp_srv",
    "rkvenc-ccu@fdbf0000": "rkvenc_ccu",
    "rkvdec-ccu@fdc30000": "rkvdec_ccu",
    "spdif-tx@fddb0000": "spdif_tx2",
    "i2s@fddf0000": "i2s5_8ch",
    "i2s@fddf4000": "i2s6_8ch",
    "i2s@fddf8000": "i2s7_8ch",
    "saradc@fec10000": "saradc",
    "dfi@fe060000": "dfi",
    "dmc": "dmc",
    "vop@fdd90000": "vop",
    "iommu@fdd97e00": "vop_mmu",
    "serial@feb90000": "uart6",
    "phy@fee00000": "combphy0_ps",
    "phy@fee10000": "combphy1_ps",
    "phy@fee20000": "combphy2_psu",
    "av1d@fdc70000": "av1d",
    "av1d-mmu@fdc68000": "av1d_mmu",
    "jpegd@fdb90000": "jpegd",
    "iommu@fdb90480": "jpegd_mmu",
    "iep@fdbb0000": "iep",
    "iommu@fdbb0800": "iep_mmu",
    "vdpu@fdb50400": "vdpu",
    "iommu@fdb50000": "vdpu_mmu",
    "iommu@fdba0800": "jpege0_mmu",
    "iommu@fdba4800": "jpege1_mmu",
    "iommu@fdba8800": "jpege2_mmu",
    "iommu@fdbac800": "jpege3_mmu",
    "iommu@fdbdf000": "rkvenc0_mmu",
    "iommu@fdbef000": "rkvenc1_mmu",
    "iommu@fdc38700": "rkvdec0_mmu",
    "iommu@fdc48700": "rkvdec1_mmu",
    "rga@fdb80000": "rga2",
    "rga@fdb60000": "rga3_core0",
    "iommu@fdb60f00": "rga3_0_mmu",
    "rga@fdb70000": "rga3_core1",
    "iommu@fdb70f00": "rga3_1_mmu",
}
COMPATIBLE_TARGETS = {
    "rockchip,vpu-jpege-ccu": "jpege_ccu",
    "rockchip,mpp-service": "mpp_srv",
    "rockchip,rkvenc-ccu": "rkvenc_ccu",
    "rockchip,rkvdec-ccu": "rkvdec_ccu",
    "rockchip,av1-decoder": "av1d",
    "rockchip,iommu-av1d": "av1d_mmu",
    "rockchip,iep-v2": "iep",
    "rockchip,vpu-jpeg-decoder": "jpegd",
    "rockchip,vpu-encoder": "vdpu",
    "rockchip,rga3_core0": "rga3_core0",
    "rockchip,rga3_core1": "rga3_core1",
}
STATUS_ONLY_TARGETS = {
    "av1d",
    "av1d_mmu",
    "combphy0_ps",
    "combphy1_ps",
    "combphy2_psu",
    "dfi",
    "dp0",
    "dp0_in_vp2",
    "hdmi0_in_vp0",
    "hdmi0_in_vp1",
    "hdmi0_in_vp2",
    "hdmi0_sound",
    "hdmi1_in_vp0",
    "hdmi1_in_vp1",
    "hdmi1_in_vp2",
    "hdmi1_sound",
    "hdptxphy_hdmi0",
    "hdptxphy_hdmi1",
    "i2s5_8ch",
    "i2s6_8ch",
    "i2s7_8ch",
    "iep",
    "iep_mmu",
    "jpegd",
    "jpegd_mmu",
    "jpege_ccu",
    "jpege0",
    "jpege0_mmu",
    "jpege1",
    "jpege1_mmu",
    "jpege2",
    "jpege2_mmu",
    "jpege3",
    "jpege3_mmu",
    "mpp_srv",
    "pcie30phy",
    "rga2",
    "rga3_0_mmu",
    "rga3_1_mmu",
    "rga3_core0",
    "rga3_core1",
    "rknpu_mmu",
    "rkvdec0",
    "rkvdec0_mmu",
    "rkvdec1",
    "rkvdec1_mmu",
    "rkvdec_ccu",
    "rkvenc0",
    "rkvenc0_mmu",
    "rkvenc1",
    "rkvenc1_mmu",
    "rkvenc_ccu",
    "saradc",
    "spdif_tx2",
    "tsadc",
    "u2phy0",
    "u2phy1",
    "u2phy2",
    "u2phy2_host",
    "u2phy3",
    "u2phy3_host",
    "usb_host0_ehci",
    "usb_host0_ohci",
    "usb_host1_ehci",
    "usb_host1_ohci",
    "usbdrd3_0",
    "usbdrd3_1",
    "usbdp_phy0_dp",
    "usbdp_phy0_u3",
    "usbdp_phy1_u3",
    "usbhost3_0",
    "usbhost_dwc3_0",
    "uart6",
    "vdpu",
    "vdpu_mmu",
    "vop",
    "vop_mmu",
}
MINIMAL_OVERLAY_PROPERTIES = {
    "cpu_b0": {"cpu-supply", "mem-supply"},
    "cpu_b2": {"cpu-supply", "mem-supply"},
    "cpu_l0": {"cpu-supply", "mem-supply"},
    "dmc": {"center-supply", "mem-supply", "status"},
    "display_subsystem": {"clocks", "clock-names"},
    "gpio0": {"gpio-line-names"},
    "gpio1": {"gpio-line-names"},
    "gpio2": {"gpio-line-names"},
    "gpio3": {"gpio-line-names"},
    "gpio4": {"gpio-line-names"},
    "hdmi0": {"status", "cec-enable", "enable-gpios"},
    "hdmi1": {"status", "pinctrl-names", "pinctrl-0", "cec-enable", "enable-gpios"},
    "hdmirx_ctrler": {"status", "hpd-trigger-level", "hdmirx-det-gpios", "pinctrl-0", "pinctrl-names", "#sound-dai-cells"},
    "i2c0": {"status", "pinctrl-names", "pinctrl-0"},
    "i2c1": {"status", "pinctrl-names", "pinctrl-0"},
    "i2c4": {"status", "pinctrl-names", "pinctrl-0"},
    "i2s0_8ch": {"status", "#sound-dai-cells", "pinctrl-0", "pinctrl-names", "rockchip,capture-channels", "rockchip,playback-channels"},
    "pcie2x1l0": {"status", "reset-gpios", "vpcie3v3-supply"},
    "pcie2x1l2": {"status", "reset-gpios", "vpcie3v3-supply"},
    "pcie3x4": {"status", "reset-gpios", "vpcie3v3-supply"},
    "pwm1": {"status", "pinctrl-0", "pinctrl-names"},
    "route_dp0": {"status", "connect"},
    "saradc": {"status", "vref-supply"},
    "sdhci": {"bus-width", "no-sdio", "no-sd", "non-removable", "max-frequency", "mmc-hs400-1_8v", "mmc-hs400-enhanced-strobe", "mmc-hs200-1_8v", "status"},
    "sdio": {"max-frequency", "supports-sdio", "bus-width", "disable-wp", "cap-sd-highspeed", "cap-sdio-irq", "keep-power-in-suspend", "mmc-pwrseq", "non-removable", "num-slots", "pinctrl-names", "pinctrl-0", "sd-uhs-sdr104", "status"},
    "sdmmc": {"max-frequency", "no-sdio", "no-mmc", "bus-width", "cap-mmc-highspeed", "cap-sd-highspeed", "disable-wp", "sd-uhs-sdr104", "vmmc-supply", "vqmmc-supply", "pinctrl-names", "pinctrl-0", "status"},
    "u2phy0_otg": {"rockchip,typec-vbus-det", "status"},
    "u2phy1_otg": {"vbus-supply", "status"},
    "usbdrd_dwc3_0": {"status", "dr_mode", "usb-role-switch"},
    "usbdrd_dwc3_1": {"status"},
    "usbdp_phy0": {"status", "orientation-switch", "svid", "sbu1-dc-gpios", "sbu2-dc-gpios"},
    "usbdp_phy1": {"status"},
}
EMPTY_OVERLAY_TARGETS = {
    "avcc_1v8_s0",
    "avdd_0v75_s0",
    "vcc_1v8_s0",
    "vcc_3v3_s0",
    "vdd_ddr_pll_s0",
    "vdd_log_s0",
}
ALLOWED_DUMP_OVERLAY_TARGETS = STATUS_ONLY_TARGETS | set(MINIMAL_OVERLAY_PROPERTIES) | {
    "cpu_b0",
    "cpu_b2",
    "cpu_l0",
    "gpu",
    "rknpu",
    "rknpu_mmu",
    "hdmirx_ctrler",
} | EMPTY_OVERLAY_TARGETS


def default_output_path(input_path: Path, mode: str) -> Path:
    if mode == "dump-cleanup":
        if input_path.name.endswith(".dumped.dts"):
            return input_path.with_name(input_path.name[: -len(".dumped.dts")] + ".dts")
        if input_path.name.endswith(".dts.dumped"):
            return input_path.with_name(input_path.name[: -len(".dumped")])
        return input_path.with_name(input_path.stem + ".cleaned.dts")
    return input_path.with_name(input_path.stem + ".mainline.dts")


def infer_mode(input_path: Path, explicit_mode: str | None) -> str:
    if explicit_mode:
        return explicit_mode
    if "fdtdump" in input_path.parts:
        return "dump-cleanup"
    if input_path.name.endswith(".dumped.dts"):
        return "dump-cleanup"
    if input_path.name.endswith(".dts.dumped"):
        return "dump-cleanup"
    return "vendor-to-mainline"


def has_single_rk806_scheme(content: str) -> bool:
    if 'rk806single@0' not in content:
        return False
    if "spi@feb20000" not in content:
        return False
    if "rk806master@0" in content or "rk806slave@1" in content:
        return False
    return all(f'regulator-name = "{name}";' in content for name in SINGLE_RK806_REQUIRED_NAMES)


def has_dual_rk806_scheme(content: str) -> bool:
    if "rk806master@0" not in content or "rk806slave@1" not in content:
        return False
    if "spi@feb20000" not in content:
        return False
    return True


def build_dump_cleanup_model(content: str, soc_family: str) -> BoardModel:
    phandle_labels = build_phandle_label_map(content)
    alias_targets = build_dump_alias_target_map(content)
    model = BoardModel(
        source_kind="dump-cleanup",
        soc=soc_family,
        model=find_model(content, "Unknown RK3588 Board"),
        compatibles=find_compatible_list(content) or [f"unknown,{soc_family}-board", f"rockchip,{soc_family}"],
        includes=default_dump_cleanup_includes(soc_family),
    )
    chosen = extract_chosen_stdout(content)
    if chosen:
        model.root_nodes.append(NodeFact(name="chosen", block=chosen, category="core"))

    recovered_root_nodes = recover_dump_root_nodes(content, phandle_labels, alias_targets)
    append_unique_root_nodes(model, recovered_root_nodes)

    if has_single_rk806_scheme(content):
        model.includes.append('"rk3588-rk806-single.dtsi"')
        for block in build_fixed_regulator_blocks():
            append_unique_root_nodes(
                model,
                [NodeFact(name=_node_name(block), block=block, category="regulator")],
            )
        overlays = build_rk860x_overlays(content)
        model.overlays.extend(overlays)
        model.overlays.extend(build_supply_overlays(content))
    elif has_dual_rk806_scheme(content):
        model.includes.append('"rk3588-rk806-dual.dtsi"')

    for node_name, target in (("tsadc@fec00000", "tsadc"),):
        block = extract_block(content, node_name)
        if block and property_value(block, "status") == '"okay"':
            model.overlays.append(
                OverlayFact(target=target, block=f'&{target} {{\n\tstatus = "okay";\n}};\n', category="enabled-node", enabled=True)
            )

    model.overlays.extend(build_imported_node_overlays(content, phandle_labels))
    model.overlays.extend(build_nested_dump_overlays(content, phandle_labels))
    model.overlays.extend(build_helper_node_overlays(content, phandle_labels))
    model.overlays.extend(build_common_dump_overlays(content, phandle_labels))
    model.overlays.extend(build_rockchip_suspend_overlay(content))

    if not model.overlays:
        model.unresolved.append(UnresolvedFact(kind="coverage", detail="No dump-specific overlays were recognized"))
    return model


def recover_dump_root_nodes(
    content: str,
    phandle_labels: dict[str, str],
    alias_targets: dict[str, str],
) -> list[NodeFact]:
    recovered: list[NodeFact] = []
    for block in iter_root_blocks(content):
        name = _node_name(block)
        category = classify_block(block)
        if not should_restore_dump_root_node(name, category, block, alias_targets):
            continue
        normalized = normalize_dump_root_block(block, phandle_labels)
        recovered.append(
            NodeFact(
                name=_node_name(normalized),
                block=normalized,
                category=category,
            )
        )
    return recovered


def should_restore_dump_root_node(
    name: str,
    category: str,
    block: str,
    alias_targets: dict[str, str],
) -> bool:
    if name == "sdio-pwrseq":
        return True
    if property_value(block, "status") == '"disabled"':
        return False
    if name in {"chosen", "aliases", "clocks"}:
        return False
    if infer_dump_overlay_target(block, alias_targets):
        return False
    if name == "reserved-memory":
        return True
    if category in {"audio", "fan", "mmc-pwrseq", "leds", "wireless"}:
        return True
    if category == "regulator":
        return True
    if "rockchip,multicodecs-card" in (property_value(block, "compatible") or ""):
        return True
    return False


def normalize_dump_root_block(block: str, phandle_labels: dict[str, str]) -> str:
    block = block.replace("\t", "    ").strip()
    block = ensure_root_block_label(block)
    block = strip_phandle_properties(block)
    block = "\n".join(
        line for line in block.splitlines() if line.strip() != 'status = "disabled";'
    )
    block = replace_numeric_phandles(block, phandle_labels)
    return normalize_block_header(block) + "\n"


def strip_phandle_properties(block: str) -> str:
    lines = [line for line in block.splitlines() if "phandle =" not in line]
    return "\n".join(lines)


def replace_numeric_phandles(block: str, phandle_labels: dict[str, str]) -> str:
    rewritten_lines: list[str] = []
    for line in block.splitlines():
        rewritten_lines.append(rewrite_phandle_line(line, phandle_labels))
    return "\n".join(rewritten_lines)


def rewrite_phandle_line(line: str, phandle_labels: dict[str, str]) -> str:
    if "=" not in line or "<" not in line or ">" not in line:
        return line
    name, remainder = line.split("=", 1)
    property_name = name.strip()
    match = ANGLE_VALUE_RE.search(remainder)
    if not match:
        return line
    tokens = match.group(1).split()
    rewritten_tokens = tokens[:]

    if property_name in WHOLE_LIST_PHANDLE_PROPERTIES or (
        property_name == "clocks" and all(phandle_labels.get(token.lower()) for token in tokens)
    ):
        changed = False
        for index, token in enumerate(tokens):
            label = phandle_labels.get(token.lower())
            if not label:
                continue
            rewritten_tokens[index] = f"&{label}"
            changed = True
        if not changed:
            return line
    elif (property_name in FIRST_TOKEN_PHANDLE_PROPERTIES or property_name.endswith("-supply")) and tokens:
        label = phandle_labels.get(tokens[0].lower())
        if not label:
            return line
        rewritten_tokens[0] = f"&{label}"
        rewritten_tokens = rewrite_gpio_tokens(property_name, rewritten_tokens)
    else:
        return line

    return name + "=" + remainder[: match.start()] + "<" + " ".join(rewritten_tokens) + ">" + remainder[match.end() :]


def rewrite_gpio_tokens(property_name: str, tokens: list[str]) -> list[str]:
    if property_name not in {
        "WIFI,host_wake_irq",
        "enable-gpios",
        "gpio",
        "gpios",
        "hdmirx-det-gpios",
        "host-wakeup-gpios",
        "hp-det-gpio",
        "int-n-gpios",
        "reset-gpios",
        "sbu1-dc-gpios",
        "sbu2-dc-gpios",
        "shutdown-gpios",
    }:
        return tokens
    if len(tokens) < 3:
        return tokens
    pin_macro = gpio_pin_macro(tokens[1])
    active_macro = gpio_active_macro(tokens[2])
    rewritten = tokens[:]
    if pin_macro:
        rewritten[1] = pin_macro
    if active_macro:
        rewritten[2] = active_macro
    return rewritten


def gpio_pin_macro(token: str) -> str | None:
    try:
        index = int(token, 0)
    except ValueError:
        return None
    if index < 0 or index > 31:
        return None
    bank = "ABCD"[index // 8]
    return f"RK_P{bank}{index % 8}"


def gpio_active_macro(token: str) -> str | None:
    try:
        value = int(token, 0)
    except ValueError:
        return None
    if value == 0:
        return "GPIO_ACTIVE_HIGH"
    if value == 1:
        return "GPIO_ACTIVE_LOW"
    return None


def ensure_root_block_label(block: str) -> str:
    label = infer_root_block_label(block)
    if not label:
        return block
    lines = block.splitlines()
    if not lines:
        return block
    header = lines[0]
    if ":" in header.split("{", 1)[0]:
        return block
    left, right = header.split("{", 1)
    lines[0] = f"{label}: {left.strip()} {{" + right
    return "\n".join(lines)


def infer_root_block_label(block: str) -> str | None:
    name = _node_name(block)
    label = ROOT_NODE_LABELS.get(name)
    if label:
        return label
    regulator_name = property_value(block, "regulator-name")
    if regulator_name:
        return normalize_label_name(regulator_name.strip().strip('"'))
    return None


def build_phandle_label_map(content: str) -> dict[str, str]:
    phandle_labels: dict[str, str] = {}
    alias_targets = build_dump_alias_target_map(content)
    for block in iter_all_blocks(content):
        phandle = property_value(block, "phandle")
        if not phandle:
            continue
        key = phandle.strip("<>").strip().lower()
        if not key.startswith("0x"):
            continue
        label = infer_node_label(block, alias_targets)
        if label:
            phandle_labels[key] = label
            phandle_labels[str(int(key, 16))] = label
    pinctrl_block = extract_block(content, "pinctrl")
    if pinctrl_block:
        for block in iter_all_blocks(pinctrl_block):
            phandle = property_value(block, "phandle")
            if not phandle:
                continue
            if direct_child_blocks(block):
                continue
            key = phandle.strip("<>").strip().lower()
            if not key.startswith("0x"):
                continue
            label = normalize_label_name(_node_name(block))
            if label and key not in phandle_labels:
                phandle_labels[key] = label
                phandle_labels[str(int(key, 16))] = label
    return phandle_labels


def iter_all_blocks(content: str) -> list[str]:
    blocks: list[str] = []
    pattern = re.compile(r"^[ \t]*(?:[\w,\-]+:\s+)*[/\w,\-@]+(?:\s*:\s*[\w,\-@]+)?\s*\{", re.MULTILINE)
    for match in pattern.finditer(content):
        block = extract_block_from_index(content, match.start())
        if block:
            blocks.append(block)
    return blocks


def infer_node_label(block: str, alias_targets: dict[str, str]) -> str | None:
    node_name = _node_name(block)
    if node_name in KNOWN_PHANDLE_LABELS:
        return KNOWN_PHANDLE_LABELS[node_name]
    if node_name in ROOT_NODE_LABELS:
        return ROOT_NODE_LABELS[node_name]
    if node_name in ROOT_NODE_TARGETS:
        return ROOT_NODE_TARGETS[node_name]
    if node_name in alias_targets:
        return alias_targets[node_name]
    regulator_name = property_value(block, "regulator-name")
    if regulator_name:
        return regulator_name.strip().strip('"')
    return None


def normalize_label_name(node_name: str) -> str | None:
    stripped = node_name.split("@", 1)[0].strip()
    if not stripped:
        return None
    normalized = stripped.replace("-", "_").replace(",", "_")
    normalized = re.sub(r"[^0-9A-Za-z_]+", "_", normalized).strip("_")
    if not normalized:
        return None
    if normalized[0].isdigit():
        return None
    return normalized


def append_unique_root_nodes(model: BoardModel, nodes: list[NodeFact]) -> None:
    existing = {node.name for node in model.root_nodes}
    for node in nodes:
        if node.name in existing:
            continue
        model.root_nodes.append(node)
        existing.add(node.name)


def replace_or_append_root_nodes(model: BoardModel, nodes: list[NodeFact]) -> None:
    existing = {node.name: index for index, node in enumerate(model.root_nodes)}
    for node in nodes:
        index = existing.get(node.name)
        if index is None:
            model.root_nodes.append(node)
            existing[node.name] = len(model.root_nodes) - 1
            continue
        model.root_nodes[index] = node


def build_vendor_to_mainline_model(
    content: str,
    soc_family: str,
    reference_model: BoardModel | None = None,
) -> BoardModel:
    compatibles = find_compatible_list(content)
    model = BoardModel(
        source_kind="vendor-to-mainline",
        soc=soc_family,
        model=reference_model.model if reference_model else find_model(content, f"Unknown {soc_family.upper()} Board"),
        compatibles=reference_model.compatibles[:] if reference_model else normalize_vendor_compatibles(compatibles, soc_family),
        includes=ensure_required_includes(
            content,
            reference_model.includes[:] if reference_model else select_mainline_includes(content, soc_family),
        ),
    )
    model.aliases = reference_model.aliases.copy() if reference_model and reference_model.aliases else parse_aliases(content)
    reference_root_ids = root_identity_set(reference_model.root_nodes) if reference_model else None
    reference_overlay_ids = overlay_identity_set(reference_model.overlays) if reference_model else None
    reference_root_lookup = root_identity_lookup(reference_model.root_nodes) if reference_model else {}
    provided_reference_labels = collect_defined_labels(reference_model.root_nodes) if reference_model else set()
    deferred_root_nodes: list[NodeFact] = []

    for block in iter_root_blocks(content):
        if should_skip_root_block(block):
            continue
        node_name = _node_name(block)
        category = classify_block(block)
        normalized_block = normalize_root_block(block)
        node = NodeFact(name=node_name, block=normalized_block, category=category)
        identity = node_identity(node)
        if reference_root_ids is not None and identity not in reference_root_ids:
            deferred_root_nodes.append(node)
            continue
        if identity in reference_root_lookup:
            reference_name = reference_root_lookup[identity].name
            if reference_name != node.name:
                node.block = rename_node_block(node.block, reference_name)
                node.name = reference_name
        model.root_nodes.append(node)

    for target, block in iter_overlay_blocks(content):
        if not should_keep_overlay(target, block):
            continue
        normalized = normalize_overlay_block(block)
        overlay = OverlayFact(
            target=target,
            block=normalized,
            category=classify_block(normalized),
            enabled=has_property(normalized, "status") and property_value(normalized, "status") == '"okay"',
        )
        identity = overlay_identity(overlay)
        if reference_overlay_ids is not None and identity not in reference_overlay_ids:
            model.unresolved.append(UnresolvedFact(kind="overlay", detail=f"Skipped vendor-only overlay &{target}"))
            continue
        model.overlays.append(overlay)

    referenced_labels = collect_referenced_labels(model.root_nodes, model.overlays)
    for node in deferred_root_nodes:
        labels = block_labels(node.block)
        if (
            node.category in {"mmc-pwrseq"}
            and labels
            and any(label in referenced_labels and label not in provided_reference_labels for label in labels)
        ):
            model.root_nodes.append(node)
            continue
        model.unresolved.append(
            UnresolvedFact(kind="root-node", detail=f"Skipped vendor-only root node {node.name}")
        )

    if not model.root_nodes:
        model.unresolved.append(UnresolvedFact(kind="coverage", detail="No root nodes were preserved from vendor input"))
    return model


def render_conversion(
    content: str,
    mode: str,
    soc_family: str,
    reference_model: BoardModel | None = None,
) -> tuple[BoardModel, str]:
    if mode == "dump-cleanup":
        model = build_dump_cleanup_model(content, soc_family)
    else:
        model = build_vendor_to_mainline_model(content, soc_family, reference_model=reference_model)
    return model, render_board_model(model)


def extract_reference_model(content: str, source_kind: str, soc_family: str) -> BoardModel:
    if source_kind == "dump-cleanup":
        return build_dump_cleanup_model(content, soc_family)
    return build_vendor_to_mainline_model(content, soc_family)


def extract_structural_model(content: str, soc_family: str) -> BoardModel:
    model = BoardModel(
        source_kind="structural-reference",
        soc=soc_family,
        model=find_model(content, f"Unknown {soc_family.upper()} Board"),
        compatibles=find_compatible_list(content),
        includes=find_includes(content),
    )
    model.aliases = parse_aliases(content)
    for block in iter_root_blocks(content):
        node_name = _node_name(block)
        model.root_nodes.append(
            NodeFact(
                name=node_name,
                block=normalize_root_block(block),
                category=classify_block(block),
            )
        )
    for target, block in iter_overlay_blocks(content):
        normalized = normalize_overlay_block(block)
        model.overlays.append(
            OverlayFact(
                target=target,
                block=normalized,
                category=classify_block(normalized),
                enabled=has_property(normalized, "status") and property_value(normalized, "status") == '"okay"',
            )
        )
    return model



def normalize_vendor_compatibles(compatibles: list[str], soc_family: str) -> list[str]:
    if not compatibles:
        return [f"rockchip,{soc_family}"]
    filtered = [item for item in compatibles if item not in {"rockchip,rk3588-evb1-lp4-v10", "rockchip,rk3588-linux"}]
    if not any(item == f"rockchip,{soc_family}" for item in filtered):
        filtered.append(f"rockchip,{soc_family}")
    return filtered


def select_mainline_includes(content: str, soc_family: str) -> list[str]:
    includes = find_includes(content)
    selected: list[str] = []
    for include in includes:
        if include.startswith("<") or "dt-bindings/" in include:
            selected.append(include)
            continue
        if "linux.dtsi" in include:
            continue
        if "rk3588-rk806-single.dtsi" in include and soc_family == "rk3588":
            continue
        if "rk3588-rk806-dual.dtsi" in include and soc_family == "rk3588":
            continue
        if include.endswith(".dtsi\"") or include.endswith(".dtsi>"):
            selected.append(include)
            break
    if not any(item.endswith(f'{soc_family}.dtsi"') or item.endswith(f'{soc_family}.dtsi>') for item in selected):
        selected.append(f'"{soc_family}.dtsi"')
    return ensure_required_includes(content, selected)


def ensure_required_includes(content: str, includes: list[str]) -> list[str]:
    selected = includes[:]
    if "PHY_MODE_PCIE_" in content and "<dt-bindings/phy/phy-snps-pcie3.h>" not in selected:
        selected.append("<dt-bindings/phy/phy-snps-pcie3.h>")
    return selected


def should_skip_root_block(block: str) -> bool:
    name = _node_name(block)
    compatible = property_value(block, "compatible") or ""
    if name == "chosen":
        return True
    if name == "aliases":
        return True
    if name == "reserved-memory":
        return True
    if "rockchip,debug" in compatible:
        return True
    if "rockchip,vendor-storage" in compatible or "rockchip,ram-vendor-storage" in compatible:
        return True
    return False


def should_keep_overlay(target: str, block: str) -> bool:
    denied_targets = {
        "hdmirx_ctrler",
        "hdptxphy_hdmi0",
        "hdptxphy_hdmi1",
        "i2s7_8ch",
        "usbdp_phy0_dp",
        "usbdp_phy0_u3",
        "usbdp_phy1_u3",
        "usbdrd3_0",
        "usbdrd3_1",
        "usbdrd_dwc3_0",
        "usbdrd_dwc3_1",
        "usbhost3_0",
        "usbhost_dwc3_0",
        "usbhost_dwc3_1",
        "vp0",
        "vp1",
        "vp2",
        "vp3",
    }
    if target in denied_targets or "_vp" in target:
        return False
    allowed_prefixes = (
        "combphy",
        "cpu_",
        "edp",
        "gmac",
        "gpu",
        "hdmi",
        "hdptxphy",
        "i2c",
        "i2s",
        "mdio",
        "package_thermal",
        "pcie",
        "pinctrl",
        "sata",
        "sdhci",
        "sdio",
        "sdmmc",
        "spi",
        "tsadc",
        "u2phy",
        "uart",
        "usb_",
        "usbdrd",
        "usbhost",
        "usbdp_phy",
        "vop",
        "vp",
    )
    if target.startswith(allowed_prefixes):
        return True
    compatible = property_value(block, "compatible") or ""
    if "ethernet-phy" in compatible or "hdmi-connector" in compatible:
        return True
    return False


def normalize_root_block(block: str) -> str:
    return normalize_block_header(block.replace("\t", "    ").strip()) + "\n"


def normalize_overlay_block(block: str) -> str:
    return normalize_block_header(block.replace("\t", "    ").strip()) + "\n"


def normalize_identity(value: str) -> str:
    return value.strip().strip('"').lower().replace("regulator-", "")


def node_identity(node: NodeFact) -> str:
    if node.category == "regulator":
        regulator_name = property_value(node.block, "regulator-name")
        if regulator_name:
            return f"regulator:{normalize_identity(regulator_name)}"
    if node.category == "audio":
        for prop in ("simple-audio-card,name", "rockchip,card-name", "label"):
            value = property_value(node.block, prop)
            if value:
                return f"audio:{normalize_identity(value)}"
    return f"{node.category}:{normalize_identity(node.name)}"


def overlay_identity(overlay: OverlayFact) -> str:
    return normalize_identity(overlay.target)


def root_identity_set(nodes: list[NodeFact]) -> set[str]:
    return {node_identity(node) for node in nodes}


def overlay_identity_set(overlays: list[OverlayFact]) -> set[str]:
    return {overlay_identity(overlay) for overlay in overlays}


def root_identity_lookup(nodes: list[NodeFact]) -> dict[str, NodeFact]:
    return {node_identity(node): node for node in nodes}


def rename_node_block(block: str, new_name: str) -> str:
    lines = block.splitlines()
    if not lines:
        return block
    header = lines[0]
    if "{" not in header:
        return block
    left, right = header.split("{", 1)
    parts = [part.strip() for part in left.split(":") if part.strip()]
    if len(parts) >= 2:
        lines[0] = f"{parts[0]}: {new_name} {{" + right
    else:
        lines[0] = f"{new_name} {{" + right
    return "\n".join(lines)


def block_labels(block: str) -> list[str]:
    header = block.strip().split("{", 1)[0].strip()
    parts = [part.strip() for part in header.split(":") if part.strip()]
    if len(parts) <= 1:
        return []
    return parts[:-1]


def collect_referenced_labels(root_nodes: list[NodeFact], overlays: list[OverlayFact]) -> set[str]:
    labels: set[str] = set()
    for item in root_nodes:
        labels.update(LABEL_REF_RE.findall(item.block))
    for item in overlays:
        labels.update(LABEL_REF_RE.findall(item.block))
    return labels


def collect_defined_labels(root_nodes: list[NodeFact]) -> set[str]:
    labels: set[str] = set()
    for item in root_nodes:
        labels.update(block_labels(item.block))
    return labels


def extract_chosen_stdout(content: str) -> str | None:
    chosen_block = extract_block(content, "chosen")
    stdout = property_value(chosen_block or "", "stdout-path")
    if not stdout:
        return None
    return f"chosen {{\n\tstdout-path = {stdout};\n}};\n"


def build_fixed_regulator_blocks() -> list[str]:
    return [
        (
            "vcc5v0_sys: vcc5v0-sys {\n"
            '\tcompatible = "regulator-fixed";\n'
            '\tregulator-name = "vcc5v0_sys";\n'
            "\tregulator-always-on;\n"
            "\tregulator-boot-on;\n"
            "\tregulator-min-microvolt = <5000000>;\n"
            "\tregulator-max-microvolt = <5000000>;\n"
            "\tvin-supply = <&vcc12v_dcin>;\n"
            "};\n"
        ),
        (
            "vcc_1v1_nldo_s3: vcc-1v1-nldo-s3 {\n"
            '\tcompatible = "regulator-fixed";\n'
            '\tregulator-name = "vcc_1v1_nldo_s3";\n'
            "\tregulator-always-on;\n"
            "\tregulator-boot-on;\n"
            "\tregulator-min-microvolt = <1100000>;\n"
            "\tregulator-max-microvolt = <1100000>;\n"
            "\tvin-supply = <&vcc5v0_sys>;\n"
            "};\n"
        ),
    ]


def build_rk860x_overlays(content: str) -> list[OverlayFact]:
    overlays: list[OverlayFact] = []
    i2c0_block = extract_block(content, "i2c@fd880000")
    i2c1_block = extract_block(content, "i2c@fea90000")
    i2c6_block = extract_block(content, "i2c@fec80000")
    npu_block = extract_block(i2c1_block or "", "rk8602@42")
    big_bus_block = i2c0_block or i2c6_block or ""
    big_bus_target = "i2c0" if i2c0_block else "i2c6"
    big0_block = extract_block(big_bus_block, "rk8602@42")
    big1_block = extract_block(big_bus_block, "rk8603@43")

    if npu_block:
        pinctrl = render_parent_properties(i2c1_block or "", {"pinctrl-names", "pinctrl-0"})
        block = (
            "&i2c1 {\n"
            '\tstatus = "okay";\n\n'
            + pinctrl
            + render_rk860x_node(
                npu_block,
                ["vdd_npu_s0", "vdd_npu_mem_s0"],
                "rk8602@42",
                "rockchip,rk8602",
            )
            + "\n};\n"
        )
        overlays.append(
            OverlayFact(
                target="i2c1",
                category="regulator",
                block=replace_numeric_phandles(block, build_phandle_label_map(content)),
                enabled=True,
            )
        )
    if big0_block or big1_block:
        body = [f"&{big_bus_target} {{", '\tstatus = "okay";', ""]
        parent_props = render_parent_properties(big_bus_block, {"pinctrl-names", "pinctrl-0"})
        if parent_props:
            body.append(parent_props.rstrip())
            body.append("")
        if big0_block:
            body.append(
                render_rk860x_node(
                    big0_block,
                    ["vdd_cpu_big0_s0", "vdd_cpu_big0_mem_s0"],
                    "rk8602@42",
                    "rockchip,rk8602",
                )
            )
            body.append("")
        if big1_block:
            body.append(
                render_rk860x_node(
                    big1_block,
                    ["vdd_cpu_big1_s0", "vdd_cpu_big1_mem_s0"],
                    "rk8603@43",
                    "rockchip,rk8603",
                )
            )
        body.append("};\n")
        block = "\n".join(body)
        overlays.append(
            OverlayFact(
                target=big_bus_target,
                block=replace_numeric_phandles(block, build_phandle_label_map(content)),
                category="regulator",
                enabled=True,
            )
        )
    return overlays


def build_supply_overlays(content: str) -> list[OverlayFact]:
    overlays: list[OverlayFact] = []
    for target, block in (
        ("cpu_l0", "&cpu_l0 {\n\tcpu-supply = <&vdd_cpu_lit_s0>;\n\tmem-supply = <&vdd_cpu_lit_mem_s0>;\n};\n"),
        ("cpu_b0", "&cpu_b0 {\n\tcpu-supply = <&vdd_cpu_big0_s0>;\n\tmem-supply = <&vdd_cpu_big0_mem_s0>;\n};\n"),
        ("cpu_b2", "&cpu_b2 {\n\tcpu-supply = <&vdd_cpu_big1_s0>;\n\tmem-supply = <&vdd_cpu_big1_mem_s0>;\n};\n"),
    ):
        overlays.append(OverlayFact(target=target, block=block, category="supply", enabled=True))

    if extract_block(content, "gpu@fb000000"):
        overlays.append(
            OverlayFact(
                target="gpu",
                block='&gpu {\n\tmali-supply = <&vdd_gpu_s0>;\n\tmem-supply = <&vdd_gpu_mem_s0>;\n\tstatus = "okay";\n};\n',
                category="supply",
                enabled=True,
            )
        )
    if extract_block(content, "rknpu@fdab0000"):
        overlays.append(
            OverlayFact(
                target="rknpu",
                block='&rknpu {\n\trknpu-supply = <&vdd_npu_s0>;\n\tmem-supply = <&vdd_npu_s0>;\n\tstatus = "okay";\n};\n',
                category="supply",
                enabled=True,
            )
        )
    return overlays


def build_imported_node_overlays(content: str, phandle_labels: dict[str, str]) -> list[OverlayFact]:
    overlays: list[OverlayFact] = []
    alias_targets = build_dump_alias_target_map(content)
    for dumped_name in IMPORTED_NODE_ORDER:
        block = extract_block(content, dumped_name)
        if not block:
            continue
        target = IMPORTED_NODE_TARGETS[dumped_name]
        if target in {"i2c0", "i2c1"}:
            continue
        normalized = convert_dumped_block_to_overlay(block, target, phandle_labels, alias_targets)
        if overlay_is_empty(normalized):
            continue
        status = property_value(block, "status")
        overlays.append(
            OverlayFact(
                target=target,
                block=normalized,
                category=classify_block(normalized),
                enabled=status == '"okay"',
            )
        )

    seen_targets = {overlay.target for overlay in overlays}
    for block in iter_root_blocks(content):
        target = infer_dump_overlay_target(block, alias_targets)
        if not target or target in seen_targets:
            continue
        if target in {"i2c0", "i2c1"} and (
            extract_block(block, "rk8602@42") or extract_block(block, "rk8603@43")
        ):
            continue
        normalized = convert_dumped_block_to_overlay(block, target, phandle_labels, alias_targets)
        if overlay_is_empty(normalized):
            continue
        status = property_value(block, "status")
        overlays.append(
            OverlayFact(
                target=target,
                block=normalized,
                category=classify_block(normalized),
                enabled=status == '"okay"',
            )
        )
        seen_targets.add(target)

    overlays.extend(build_imported_port_overlays(content, phandle_labels))
    return overlays


def build_nested_dump_overlays(content: str, phandle_labels: dict[str, str]) -> list[OverlayFact]:
    overlays: list[OverlayFact] = []
    display = extract_block(content, "display-subsystem")
    if display:
        route = extract_block(display, "route")
        route_dp0 = extract_block(route or "", "route-dp0")
        if route_dp0:
            status = property_value(route_dp0, "status") or '"okay"'
            if status == '"okay"':
                overlays.append(
                    OverlayFact(
                        target="route_dp0",
                        category="recovered-overlay",
                        block='&route_dp0 {\n\tstatus = ' + status + ';\n\tconnect = <&vp2_out_dp0>;\n};\n',
                        enabled=True,
                    )
                )

    for parent_name, phy_name, phy_target, port_name, port_target in (
        ("syscon@fd5d0000", "usb2-phy@0", "u2phy0", "otg-port", "u2phy0_otg"),
        ("syscon@fd5d4000", "usb2-phy@4000", "u2phy1", "otg-port", "u2phy1_otg"),
        ("syscon@fd5d8000", "usb2-phy@8000", "u2phy2", "host-port", "u2phy2_host"),
        ("syscon@fd5dc000", "usb2-phy@c000", "u2phy3", "host-port", "u2phy3_host"),
    ):
        parent = extract_block(content, parent_name)
        if not parent:
            continue
        phy_block = extract_block(parent, phy_name)
        if not phy_block:
            continue
        overlays.append(
            OverlayFact(
                target=phy_target,
                category="recovered-overlay",
                block=convert_dumped_block_to_overlay(phy_block, phy_target, phandle_labels),
                enabled=property_value(phy_block, "status") == '"okay"',
            )
        )
        if overlay_is_empty(overlays[-1].block):
            overlays.pop()

        port_block = extract_block(phy_block, port_name)
        if not port_block:
            continue
        overlays.append(
            OverlayFact(
                target=port_target,
                category="recovered-overlay",
                block=convert_dumped_block_to_overlay(port_block, port_target, phandle_labels),
                enabled=property_value(port_block, "status") == '"okay"',
            )
        )
        if overlay_is_empty(overlays[-1].block):
            overlays.pop()

    for block in iter_all_blocks(content):
        regulator_name = property_value(block, "regulator-name")
        if not regulator_name:
            continue
        target = regulator_name.strip().strip('"')
        if target not in EMPTY_OVERLAY_TARGETS:
            continue
        overlays.append(
            OverlayFact(
                target=target,
                category="recovered-overlay",
                block=f"&{target} {{\n}};\n",
                enabled=False,
            )
        )
    return overlays


def build_helper_node_overlays(content: str, phandle_labels: dict[str, str]) -> list[OverlayFact]:
    overlays: list[OverlayFact] = []

    for target, node_name, label in (
        ("i2c6", "hym8563@51", "hym8563"),
        ("i2c7", "es8316@11", "es8316"),
    ):
        block = extract_block(content, node_name)
        if not block:
            continue
        overlays.append(
            OverlayFact(
                target=target,
                category="helper-node",
                block=(
                    f"&{target} {{\n"
                    '\tstatus = "okay";\n\n'
                    + render_labeled_child_block(block, label, phandle_labels)
                    + "\n};\n"
                ),
                enabled=True,
            )
        )

    pinctrl_children: list[tuple[str, str]] = []
    for parent_name, node_name, label in (
        ("usb", "vcc5v0-host-en", "vcc5v0_host_en"),
        ("usb", "vcc5v0-otg-en", "vcc5v0_otg_en"),
        ("usb", "vcc5v0-u2host-en", "vcc5v0_u2host_en"),
        ("usb", "vcc5v0-u3host-en", "vcc5v0_u3host_en"),
        ("usb", "vcc5v0-usb-en", "vcc5v0_usb_en"),
        ("vcc5v0-buck", "vcc5v0-buck-en", "vcc5v0_buck_en"),
        ("vcc4v0-mode", "vcc4v0-sys-mode-en", "vcc4v0_sys_mode_en"),
        ("usb-typec", "typec5v-pwren", "typec5v_pwren"),
        ("cam", "mipicsi0-pwr", "mipicsi0_pwr"),
        ("cam", "mipicsi1-pwr", "mipicsi1_pwr"),
        ("cam", "mipidcphy0-pwr", "mipidcphy0_pwr"),
        ("cam", "mipidphy0-pwr", "mipidphy0_pwr"),
        ("cam", "mipidcphy-pwr", "mipidcphy_pwr"),
        ("headphone", "hp-det", "hp_det"),
        ("hdmirx", "hdmirx-det", "hdmirx_det"),
        ("hym8563", "hym8563-int", "hym8563_int"),
        ("hym8563", "rtc-int", "rtc_int"),
        ("sdio-pwrseq", "wifi-enable-h", "wifi_enable_h"),
        ("wireless-bluetooth", "uart8-gpios", "uart8_gpios"),
        ("wireless-bluetooth", "uart6-gpios", "uart6_gpios"),
        ("wireless-bluetooth", "uart9-gpios", "uart9_gpios"),
        ("wireless-bluetooth", "uart7-gpios", "uart7_gpios"),
        ("wireless-bluetooth", "bt-gpio", "bt_gpio"),
        ("wireless-bluetooth", "bt-reset-gpio", "bt_reset_gpio"),
        ("wireless-bluetooth", "bt-wake-gpio", "bt_wake_gpio"),
        ("wireless-bluetooth", "bt-irq-gpio", "bt_irq_gpio"),
        ("wireless-wlan", "wifi-host-wake-irq", "wifi_host_wake_irq"),
        ("wireless-wlan", "wifi-poweren-gpio", "wifi_poweren_gpio"),
        ("usb", "vcc3v3-pcie30-en", "vcc3v3_pcie30_en"),
        ("usb", "vcc3v3-host32-en", "vcc3v3_host32_en"),
        ("usb", "vcc5v0-host20-en", "vcc5v0_host20_en"),
        ("usb", "vcc5v0-host30-en", "vcc5v0_host30_en"),
        ("gpio-leds", "sys-led-pin", "sys_led_pin"),
        ("gpio-leds", "usr-led-pin", "usr_led_pin"),
        ("sdmmc", "sd-s0-pwr", "sd_s0_pwr"),
        ("sdmmc", "sdmmc-pwr", "sdmmc_pwr"),
        ("leds_gpio", "leds-rgb", "leds_rgb"),
        ("leds", "leds-gpio", "leds_gpio"),
    ):
        block = extract_block(content, node_name)
        if not block:
            continue
        pinctrl_children.append((parent_name, render_labeled_child_block(block, label, phandle_labels)))

    if pinctrl_children:
        body_lines = ["&pinctrl {"]
        for parent_name, child_block in pinctrl_children:
            body_lines.append(f"\t{parent_name} {{")
            body_lines.append(indent_with_tabs(child_block.rstrip(), 2))
            body_lines.append("\t};")
            body_lines.append("")
        body_lines.append("};\n")
        overlays.append(
            OverlayFact(
                target="pinctrl",
                category="helper-node",
                block="\n".join(body_lines),
                enabled=True,
            )
        )

    return overlays


def build_common_dump_overlays(content: str, phandle_labels: dict[str, str]) -> list[OverlayFact]:
    overlays: list[OverlayFact] = []
    for dumped_name, target in (
        ("pwm@fd8b0010", "pwm1"),
        ("i2s@fe470000", "i2s0_8ch"),
        ("i2c@feac0000", "i2c4"),
        ("gpio@fd8a0000", "gpio0"),
        ("gpio@fec20000", "gpio1"),
        ("gpio@fec30000", "gpio2"),
        ("gpio@fec40000", "gpio3"),
        ("gpio@fec50000", "gpio4"),
    ):
        block = extract_block(content, dumped_name)
        if not block:
            continue
        overlays.append(
            OverlayFact(
                target=target,
                category="recovered-overlay",
                block=convert_dumped_block_to_overlay(block, target, phandle_labels),
                enabled=property_value(block, "status") == '"okay"',
            )
        )
        if overlay_is_empty(overlays[-1].block):
            overlays.pop()
    return overlays


def build_rockchip_suspend_overlay(content: str) -> list[OverlayFact]:
    if 'compatible = "rockchip,pm-rk3588";' not in content:
        return []
    return [
        OverlayFact(
            target="rockchip_suspend",
            category="recovered-overlay",
            block=(
                "&rockchip_suspend {\n"
                '\tcompatible = "rockchip,pm-rk3588";\n'
                '\tstatus = "okay";\n'
                "\trockchip,sleep-debug-en = <1>;\n"
                "\trockchip,sleep-mode-config = <\n"
                "\t\t(0\n"
                "\t\t| RKPM_SLP_ARMOFF_DDRPD\n"
                "\t\t)\n"
                "\t>;\n"
                "\trockchip,wakeup-config = <\n"
                "\t\t(0\n"
                "\t\t| RKPM_GPIO_WKUP_EN\n"
                "\t\t| RKPM_USB_WKUP_EN\n"
                "\t\t)\n"
                "\t>;\n"
                "};\n"
            ),
            enabled=True,
        )
    ]


def default_dump_cleanup_includes(soc_family: str) -> list[str]:
    return [f'"{soc_family}.dtsi"']


def build_imported_port_overlays(content: str, phandle_labels: dict[str, str]) -> list[OverlayFact]:
    overlays: list[OverlayFact] = []
    for dumped_name, dp_target, u3_target in (
        ("phy@fed80000", "usbdp_phy0_dp", "usbdp_phy0_u3"),
        ("phy@fed90000", "usbdp_phy1_dp", "usbdp_phy1_u3"),
    ):
        block = extract_block(content, dumped_name)
        if not block:
            continue
        dp_block = extract_block(block, "dp-port")
        u3_block = extract_block(block, "u3-port")
        for child_block, target in ((dp_block, dp_target), (u3_block, u3_target)):
            if not child_block:
                continue
            status = property_value(child_block, "status")
            if not status:
                continue
            overlays.append(
                OverlayFact(
                    target=target,
                    block=replace_numeric_phandles(f"&{target} {{\n\tstatus = {status};\n}};\n", phandle_labels),
                    category="enabled-node",
                    enabled=status == '"okay"',
                )
            )
    return overlays


def render_labeled_child_block(block: str, label: str, phandle_labels: dict[str, str]) -> str:
    normalized = strip_phandle_properties(block.replace("\t", "    ").strip())
    lines = normalized.splitlines()
    if not lines:
        return normalized
    header = lines[0]
    if "{" in header:
        left, right = header.split("{", 1)
        node_name = left.split(":")[-1].strip()
        lines[0] = f"{label}: {node_name} {{" + right
    normalized = "\n".join(lines)
    return replace_numeric_phandles(normalized, phandle_labels)


def indent_with_tabs(block: str, depth: int) -> str:
    prefix = "\t" * depth
    return "\n".join(f"{prefix}{line}" if line else "" for line in block.splitlines())


def render_rk860x_node(block: str, labels: list[str], node_name: str, compatible_fallback: str) -> str:
    compatible = property_value(block, "compatible") or f'"{compatible_fallback}"'
    reg = property_value(block, "reg") or "<0x0>"
    vin_supply = property_value(block, "vin-supply") or "<&vcc5v0_sys>"
    if vin_supply.startswith("<0x"):
        vin_supply = "<&vcc5v0_sys>"
    regulator_compatible = property_value(block, "regulator-compatible") or '"rk860x-reg"'
    regulator_name = property_value(block, "regulator-name") or f'"{labels[0]}"'
    min_uv = property_value(block, "regulator-min-microvolt") or "<550000>"
    max_uv = property_value(block, "regulator-max-microvolt") or "<950000>"
    ramp_delay = property_value(block, "regulator-ramp-delay") or "<2300>"
    suspend_selector = property_value(block, "rockchip,suspend-voltage-selector") or "<1>"
    label_prefix = ": ".join(labels)

    return "\n".join(
        [
            f"\t{label_prefix}: {node_name} {{",
            f"\t\tcompatible = {compatible};",
            f"\t\treg = {reg};",
            "\t\tregulator-always-on;",
            "\t\tregulator-boot-on;",
            f"\t\tregulator-compatible = {regulator_compatible};",
            f"\t\tregulator-name = {regulator_name};",
            f"\t\tregulator-min-microvolt = {min_uv};",
            f"\t\tregulator-max-microvolt = {max_uv};",
            f"\t\tregulator-ramp-delay = {ramp_delay};",
            f"\t\trockchip,suspend-voltage-selector = {suspend_selector};",
            f"\t\tvin-supply = {vin_supply};",
            "",
            "\t\tregulator-state-mem {",
            "\t\t\tregulator-off-in-suspend;",
            "\t\t};",
            "\t};",
        ]
    )


def _node_name(block: str) -> str:
    header = block.strip().split("{", 1)[0].strip()
    if ":" in header:
        header = header.split(":")[-1].strip()
    return header.split()[0]


def normalize_block_header(block: str) -> str:
    lines = block.splitlines()
    if not lines:
        return block
    header = lines[0]
    if "{" not in header:
        return block
    left, right = header.split("{", 1)
    parts = [part.strip() for part in left.split(":") if part.strip()]
    if len(parts) >= 2:
        left = f"{parts[-2]}: {parts[-1]} "
        lines[0] = left + "{" + right
    return "\n".join(lines)


def build_dump_alias_target_map(content: str) -> dict[str, str]:
    aliases_block = extract_block(content, "aliases")
    if not aliases_block:
        return {}
    targets: dict[str, str] = {}
    for alias, path in ALIASES_PATH_RE.findall(aliases_block):
        target = ALIAS_TARGET_RENAMES.get(alias, alias)
        if not path.startswith("/"):
            continue
        basename = path.rsplit("/", 1)[-1]
        targets[basename] = target
    return targets


def infer_dump_overlay_target(block: str, alias_targets: dict[str, str]) -> str | None:
    node_name = _node_name(block)
    if node_name in ROOT_NODE_TARGETS:
        target = ROOT_NODE_TARGETS[node_name]
        return target if target in ALLOWED_DUMP_OVERLAY_TARGETS else None
    if node_name in alias_targets:
        target = alias_targets[node_name]
        return target if target in ALLOWED_DUMP_OVERLAY_TARGETS else None
    compatible = property_value(block, "compatible")
    if compatible:
        for candidate, target in COMPATIBLE_TARGETS.items():
            if candidate in compatible:
                return target if target in ALLOWED_DUMP_OVERLAY_TARGETS else None
    regulator_name = property_value(block, "regulator-name")
    if regulator_name:
        target = regulator_name.strip().strip('"')
        return target if target in EMPTY_OVERLAY_TARGETS else None
    return None


def convert_dumped_block_to_overlay(
    block: str,
    target: str,
    phandle_labels: dict[str, str],
    alias_targets: dict[str, str] | None = None,
) -> str:
    body_lines = filtered_overlay_body_lines(block, target, alias_targets or {})
    body = "\n".join(body_lines).rstrip()
    if body:
        return replace_numeric_phandles(f"&{target} {{\n{body}\n}};\n", phandle_labels)
    return f"&{target} {{\n}};\n"


def filtered_overlay_body_lines(block: str, target: str, alias_targets: dict[str, str]) -> list[str]:
    property_lines = direct_property_lines(block)
    if target in STATUS_ONLY_TARGETS:
        status = property_value(block, "status")
        return [f'\tstatus = {status};'] if status == '"okay"' else []
    if target in EMPTY_OVERLAY_TARGETS:
        return []

    allowed = MINIMAL_OVERLAY_PROPERTIES.get(target)
    if allowed is None:
        return [
            line
            for line in property_lines
            if "phandle =" not in line and line.strip() != 'status = "disabled";'
        ]

    selected = render_allowed_properties(block, allowed)
    return selected


def property_name_from_line(line: str) -> str | None:
    if line.endswith("{") or line == "};":
        return None
    if "=" in line:
        return line.split("=", 1)[0].strip()
    if line.endswith(";"):
        return line[:-1].strip()
    return None


def direct_child_blocks(block: str) -> list[str]:
    brace_index = block.find("{")
    end_index = block.rfind("}")
    if brace_index == -1 or end_index == -1 or end_index <= brace_index:
        return []
    inner = block[brace_index + 1 : end_index]
    blocks: list[str] = []
    depth = 0
    start: int | None = None
    index = 0
    while index < len(inner):
        char = inner[index]
        if char == "{":
            if depth == 0:
                line_start = inner.rfind("\n", 0, index) + 1
                while line_start < index and inner[line_start] in " \t":
                    line_start += 1
                start = line_start
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0 and start is not None:
                end = index + 1
                if end < len(inner) and inner[end] == ";":
                    end += 1
                blocks.append(inner[start:end].strip() + "\n")
                start = None
        index += 1
    return blocks


def direct_property_lines(block: str) -> list[str]:
    lines = block.splitlines()
    collected: list[str] = []
    depth = 0
    for line in lines[1:]:
        stripped = line.strip()
        open_count = line.count("{")
        close_count = line.count("}")
        if depth == 0 and stripped and stripped != "};" and "{" not in stripped and "}" not in stripped:
            collected.append(line)
        depth += open_count - close_count
        if depth < 0:
            depth = 0
    return collected


def render_allowed_properties(block: str, allowed: set[str]) -> list[str]:
    rendered: list[str] = []
    for name in allowed:
        value = property_value(block, name)
        if name == "status" and value != '"okay"':
            continue
        if value is not None:
            rendered.append(f"\t{name} = {value};")
            continue
        if has_property(block, name):
            rendered.append(f"\t{name};")
    return rendered


def overlay_is_empty(block: str) -> bool:
    inner = block.split("{", 1)[1].rsplit("}", 1)[0]
    return not inner.strip()


def render_parent_properties(block: str, allowed: set[str]) -> str:
    properties = render_allowed_properties(block, allowed)
    if not properties:
        return ""
    return "\n".join(properties) + "\n"
