from __future__ import annotations

from pathlib import Path
import re

from .board_model import BoardModel, NodeFact, OverlayFact, UnresolvedFact
from .classify import classify_block
from .parse import (
    detect_soc_family,
    extract_block,
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
    "clocks",
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


def default_output_path(input_path: Path, mode: str) -> Path:
    if mode == "dump-cleanup":
        if input_path.name.endswith(".dts.dumped"):
            return input_path.with_name(input_path.name[: -len(".dumped")])
        return input_path.with_name(input_path.stem + ".cleaned.dts")
    return input_path.with_name(input_path.stem + ".mainline.dts")


def infer_mode(input_path: Path, explicit_mode: str | None) -> str:
    if explicit_mode:
        return explicit_mode
    if "fdtdump" in input_path.parts:
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


def build_dump_cleanup_model(content: str, soc_family: str) -> BoardModel:
    phandle_labels = build_phandle_label_map(content)
    model = BoardModel(
        source_kind="dump-cleanup",
        soc=soc_family,
        model=find_model(content, "Unknown RK3588 Board"),
        compatibles=find_compatible_list(content) or [f"unknown,{soc_family}-board", f"rockchip,{soc_family}"],
        includes=[f'"{soc_family}.dtsi"'],
    )
    chosen = extract_chosen_stdout(content)
    if chosen:
        model.root_nodes.append(NodeFact(name="chosen", block=chosen, category="core"))

    recovered_root_nodes = recover_dump_root_nodes(content, phandle_labels)
    append_unique_root_nodes(model, recovered_root_nodes)

    if soc_family == "rk3588" and has_single_rk806_scheme(content):
        model.includes.append('"rk3588-rk806-single.dtsi"')
        for block in build_fixed_regulator_blocks():
            replace_or_append_root_nodes(
                model,
                [NodeFact(name=_node_name(block), block=block, category="regulator")],
            )
        overlays = build_rk860x_overlays(content)
        model.overlays.extend(overlays)
        model.overlays.extend(build_supply_overlays(content))

    for node_name, target in (("tsadc@fec00000", "tsadc"),):
        block = extract_block(content, node_name)
        if block and property_value(block, "status") == '"okay"':
            model.overlays.append(
                OverlayFact(target=target, block=f'&{target} {{\n\tstatus = "okay";\n}};\n', category="enabled-node", enabled=True)
            )

    model.overlays.extend(build_imported_node_overlays(content, phandle_labels))
    model.overlays.extend(build_helper_node_overlays(content, phandle_labels))
    model.overlays.extend(build_common_dump_overlays(content, phandle_labels))

    if not model.overlays:
        model.unresolved.append(UnresolvedFact(kind="coverage", detail="No dump-specific overlays were recognized"))
    return model


def recover_dump_root_nodes(content: str, phandle_labels: dict[str, str]) -> list[NodeFact]:
    recovered: list[NodeFact] = []
    for block in iter_root_blocks(content):
        name = _node_name(block)
        category = classify_block(block)
        if not should_restore_dump_root_node(name, category, block):
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


def should_restore_dump_root_node(name: str, category: str, block: str) -> bool:
    if name in {"chosen", "aliases", "clocks"}:
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

    if property_name in WHOLE_LIST_PHANDLE_PROPERTIES:
        changed = False
        for index, token in enumerate(tokens):
            label = phandle_labels.get(token.lower())
            if not label:
                continue
            rewritten_tokens[index] = f"&{label}"
            changed = True
        if not changed:
            return line
    elif property_name in FIRST_TOKEN_PHANDLE_PROPERTIES and tokens:
        label = phandle_labels.get(tokens[0].lower())
        if not label:
            return line
        rewritten_tokens[0] = f"&{label}"
    else:
        return line

    return name + "=" + remainder[: match.start()] + "<" + " ".join(rewritten_tokens) + ">" + remainder[match.end() :]


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
    return ROOT_NODE_LABELS.get(name)


def build_phandle_label_map(content: str) -> dict[str, str]:
    phandle_labels: dict[str, str] = {}
    for node_name, label in KNOWN_PHANDLE_LABELS.items():
        block = extract_block(content, node_name)
        if not block:
            continue
        phandle = property_value(block, "phandle")
        if not phandle:
            continue
        key = phandle.strip("<>").strip().lower()
        if key.startswith("0x"):
            phandle_labels[key] = label
    return phandle_labels


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
        overlays.append(
            OverlayFact(
                target="i2c1",
                category="regulator",
                block=(
                    "&i2c1 {\n"
                    '\tstatus = "okay";\n\n'
                    + render_rk860x_node(
                        npu_block,
                        ["vdd_npu_s0", "vdd_npu_mem_s0"],
                        "rk8602@42",
                        "rockchip,rk8602",
                    )
                    + "\n};\n"
                ),
                enabled=True,
            )
        )
    if big0_block or big1_block:
        body = [f"&{big_bus_target} {{", '\tstatus = "okay";', ""]
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
        overlays.append(
            OverlayFact(
                target=big_bus_target,
                block="\n".join(body),
                category="regulator",
                enabled=True,
            )
        )
    return overlays


def build_supply_overlays(content: str) -> list[OverlayFact]:
    overlays: list[OverlayFact] = []
    for target, block in (
        ("cpu_l0", "&cpu_l0 {\n\tcpu-supply = <&vdd_cpu_lit_s0>;\n\tmem-supply = <&vdd_cpu_lit_s0>;\n};\n"),
        ("cpu_b0", "&cpu_b0 {\n\tcpu-supply = <&vdd_cpu_big0_s0>;\n\tmem-supply = <&vdd_cpu_big0_s0>;\n};\n"),
        ("cpu_b2", "&cpu_b2 {\n\tcpu-supply = <&vdd_cpu_big1_s0>;\n\tmem-supply = <&vdd_cpu_big1_s0>;\n};\n"),
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
    for dumped_name in IMPORTED_NODE_ORDER:
        block = extract_block(content, dumped_name)
        if not block:
            continue
        target = IMPORTED_NODE_TARGETS[dumped_name]
        normalized = convert_dumped_block_to_overlay(block, target, phandle_labels)
        status = property_value(block, "status")
        overlays.append(
            OverlayFact(
                target=target,
                block=normalized,
                category=classify_block(normalized),
                enabled=status == '"okay"',
            )
        )

    overlays.extend(build_imported_port_overlays(content, phandle_labels))
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
        ("headphone", "hp-det", "hp_det"),
        ("sdio-pwrseq", "wifi-enable-h", "wifi_enable_h"),
        ("wireless-wlan", "wifi-host-wake-irq", "wifi_host_wake_irq"),
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
    return overlays


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


def convert_dumped_block_to_overlay(block: str, target: str, phandle_labels: dict[str, str]) -> str:
    lines = block.strip().splitlines()
    if not lines:
        return f"&{target} {{\n}};\n"
    body_lines = lines[1:-1]
    body_lines = [line for line in body_lines if "phandle =" not in line]
    body = "\n".join(body_lines).rstrip()
    if body:
        return replace_numeric_phandles(f"&{target} {{\n{body}\n}};\n", phandle_labels)
    return f"&{target} {{\n}};\n"
