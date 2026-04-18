from __future__ import annotations

from pathlib import Path

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

    if soc_family == "rk3588" and has_single_rk806_scheme(content):
        model.includes.append('"rk3588-rk806-single.dtsi"')
        for block in build_fixed_regulator_blocks():
            model.root_nodes.append(NodeFact(name=_node_name(block), block=block, category="regulator"))
        overlays = build_rk860x_overlays(content)
        model.overlays.extend(overlays)
        model.overlays.extend(build_supply_overlays(content))

    for node_name, target in (("tsadc@fec00000", "tsadc"),):
        block = extract_block(content, node_name)
        if block and property_value(block, "status") == '"okay"':
            model.overlays.append(
                OverlayFact(target=target, block=f'&{target} {{\n\tstatus = "okay";\n}};\n', category="enabled-node", enabled=True)
            )

    if not model.overlays:
        model.unresolved.append(UnresolvedFact(kind="coverage", detail="No dump-specific overlays were recognized"))
    return model


def build_vendor_to_mainline_model(content: str, soc_family: str) -> BoardModel:
    compatibles = find_compatible_list(content)
    model = BoardModel(
        source_kind="vendor-to-mainline",
        soc=soc_family,
        model=find_model(content, f"Unknown {soc_family.upper()} Board"),
        compatibles=normalize_vendor_compatibles(compatibles, soc_family),
        includes=select_mainline_includes(content, soc_family),
    )
    model.aliases = parse_aliases(content)

    for block in iter_root_blocks(content):
        if should_skip_root_block(block):
            continue
        node_name = _node_name(block)
        model.root_nodes.append(
            NodeFact(name=node_name, block=normalize_root_block(block), category=classify_block(block))
        )

    for target, block in iter_overlay_blocks(content):
        if not should_keep_overlay(target, block):
            continue
        normalized = normalize_overlay_block(block)
        model.overlays.append(
            OverlayFact(
                target=target,
                block=normalized,
                category=classify_block(normalized),
                enabled=has_property(normalized, "status") and property_value(normalized, "status") == '"okay"',
            )
        )

    if not model.root_nodes:
        model.unresolved.append(UnresolvedFact(kind="coverage", detail="No root nodes were preserved from vendor input"))
    return model


def render_conversion(content: str, mode: str, soc_family: str) -> tuple[BoardModel, str]:
    if mode == "dump-cleanup":
        model = build_dump_cleanup_model(content, soc_family)
    else:
        model = build_vendor_to_mainline_model(content, soc_family)
    return model, render_board_model(model)


def extract_reference_model(content: str, source_kind: str, soc_family: str) -> BoardModel:
    if source_kind == "dump-cleanup":
        return build_dump_cleanup_model(content, soc_family)
    return build_vendor_to_mainline_model(content, soc_family)


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
    i2c1_block = extract_block(content, "i2c@fea90000")
    i2c6_block = extract_block(content, "i2c@fec80000")
    npu_block = extract_block(i2c1_block or "", "rk8602@42")
    big0_block = extract_block(i2c6_block or "", "rk8602@42")
    big1_block = extract_block(i2c6_block or "", "rk8603@43")

    if npu_block:
        overlays.append(
            OverlayFact(
                target="i2c1",
                category="regulator",
                block=(
                    "&i2c1 {\n"
                    '\tstatus = "okay";\n\n'
                    + render_rk860x_node(npu_block, "vdd_npu_s0", "rk8602@42", "rockchip,rk8602")
                    + "\n};\n"
                ),
                enabled=True,
            )
        )
    if big0_block or big1_block:
        body = ['&i2c6 {', '\tstatus = "okay";', ""]
        if big0_block:
            body.append(render_rk860x_node(big0_block, "vdd_cpu_big0_s0", "rk8602@42", "rockchip,rk8602"))
            body.append("")
        if big1_block:
            body.append(render_rk860x_node(big1_block, "vdd_cpu_big1_s0", "rk8603@43", "rockchip,rk8603"))
        body.append("};\n")
        overlays.append(OverlayFact(target="i2c6", block="\n".join(body), category="regulator", enabled=True))
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


def render_rk860x_node(block: str, label: str, node_name: str, compatible_fallback: str) -> str:
    compatible = property_value(block, "compatible") or f'"{compatible_fallback}"'
    reg = property_value(block, "reg") or "<0x0>"
    vin_supply = property_value(block, "vin-supply") or "<&vcc5v0_sys>"
    if vin_supply.startswith("<0x"):
        vin_supply = "<&vcc5v0_sys>"
    regulator_compatible = property_value(block, "regulator-compatible") or '"rk860x-reg"'
    regulator_name = property_value(block, "regulator-name") or f'"{label}"'
    min_uv = property_value(block, "regulator-min-microvolt") or "<550000>"
    max_uv = property_value(block, "regulator-max-microvolt") or "<950000>"
    ramp_delay = property_value(block, "regulator-ramp-delay") or "<2300>"
    suspend_selector = property_value(block, "rockchip,suspend-voltage-selector") or "<1>"

    return "\n".join(
        [
            f"\t{label}: {node_name} {{",
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
