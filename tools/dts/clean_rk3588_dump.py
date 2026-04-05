#!/usr/bin/env python3

from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import tempfile
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]

COMPATIBLE_ALL_RE = re.compile(r'"([^"]+)"')
MODEL_RE = re.compile(r'model\s*=\s*"([^"]+)";')
STDOUT_RE = re.compile(r'stdout-path\s*=\s*"([^"]+)";')
PROP_RE_TEMPLATE = r"^\s*{name}\s*=\s*([^;]+);"
BOOL_RE_TEMPLATE = r"^\s*{name}\s*;"
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


def detect_soc_family(content: str, override: str | None) -> str:
    if override:
        return override
    lowered = content.lower()
    if "rockchip,rk3588s" in lowered:
        return "rk3588s"
    return "rk3588"


def default_output_path(input_path: Path) -> Path:
    if input_path.name.endswith(".dts.dumped"):
        return input_path.with_name(input_path.name[: -len(".dumped")])
    return input_path.with_name(input_path.stem + ".cleaned.dts")


def property_value(block: str, name: str) -> str | None:
    match = re.search(PROP_RE_TEMPLATE.format(name=re.escape(name)), block, re.MULTILINE)
    if match:
        return match.group(1).strip()
    return None


def has_property(block: str, name: str) -> bool:
    return re.search(BOOL_RE_TEMPLATE.format(name=re.escape(name)), block, re.MULTILINE) is not None


def extract_block(content: str, node_name: str) -> str | None:
    match = re.search(rf"^\s*{re.escape(node_name)}\s*\{{", content, re.MULTILINE)
    if not match:
        return None
    start = match.start()
    brace_index = content.find("{", match.start())
    depth = 0
    for index in range(brace_index, len(content)):
        char = content[index]
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return content[start : index + 2]
    return None


def has_single_rk806_scheme(content: str) -> bool:
    if 'rk806single@0' not in content:
        return False
    if "spi@feb20000" not in content:
        return False
    if "rk806master@0" in content or "rk806slave@1" in content:
        return False
    return all(f'regulator-name = "{name}";' in content for name in SINGLE_RK806_REQUIRED_NAMES)


def render_fixed_regulators() -> str:
    return (
        "\tvcc5v0_sys: vcc5v0-sys {\n"
        '\t\tcompatible = "regulator-fixed";\n'
        '\t\tregulator-name = "vcc5v0_sys";\n'
        "\t\tregulator-always-on;\n"
        "\t\tregulator-boot-on;\n"
        "\t\tregulator-min-microvolt = <5000000>;\n"
        "\t\tregulator-max-microvolt = <5000000>;\n"
        "\t};\n\n"
        "\tvcc_1v1_nldo_s3: vcc-1v1-nldo-s3 {\n"
        '\t\tcompatible = "regulator-fixed";\n'
        '\t\tregulator-name = "vcc_1v1_nldo_s3";\n'
        "\t\tregulator-always-on;\n"
        "\t\tregulator-boot-on;\n"
        "\t\tregulator-min-microvolt = <1100000>;\n"
        "\t\tregulator-max-microvolt = <1100000>;\n"
        "\t\tvin-supply = <&vcc5v0_sys>;\n"
        "\t};\n"
    )


def render_rk860x_node(
    block: str,
    label: str,
    node_name: str,
    compatible_fallback: str,
) -> str:
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

    lines = [
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
    return "\n".join(lines)


def build_rk806_rk860x_output(content: str, soc_family: str) -> str:
    model_match = MODEL_RE.search(content)
    model = model_match.group(1) if model_match else "Unknown RK3588 Board"

    compatible_match = re.search(r"compatible\s*=\s*([^;]+);", content)
    compatibles = (
        COMPATIBLE_ALL_RE.findall(compatible_match.group(1)) if compatible_match else []
    )
    if not compatibles:
        compatibles = [f"unknown,{soc_family}-board", f"rockchip,{soc_family}"]

    stdout_match = STDOUT_RE.search(content)
    stdout_path = stdout_match.group(1) if stdout_match else "serial2:1500000n8"
    compatible_text = ", ".join(f'"{item}"' for item in compatibles)
    includes = [f'#include "{soc_family}.dtsi"']
    sections: list[str] = []

    root_body = (
        f'\tmodel = "{model}";\n'
        f"\tcompatible = {compatible_text};\n\n"
        "\tchosen {\n"
        f'\t\tstdout-path = "{stdout_path}";\n'
        "\t};\n"
    )

    if soc_family == "rk3588" and has_single_rk806_scheme(content):
        includes.append('#include "rk3588-rk806-single.dtsi"')
        root_body += "\n" + render_fixed_regulators()

        i2c1_block = extract_block(content, "i2c@fea90000")
        i2c6_block = extract_block(content, "i2c@fec80000")
        npu_block = extract_block(i2c1_block or "", "rk8602@42")
        big0_block = extract_block(i2c6_block or "", "rk8602@42")
        big1_block = extract_block(i2c6_block or "", "rk8603@43")

        if npu_block:
            sections.append(
                "&i2c1 {\n"
                '\tstatus = "okay";\n\n'
                + render_rk860x_node(npu_block, "vdd_npu_s0", "rk8602@42", "rockchip,rk8602")
                + "\n};\n"
            )
        if big0_block or big1_block:
            body = ['&i2c6 {', '\tstatus = "okay";', ""]
            if big0_block:
                body.append(render_rk860x_node(big0_block, "vdd_cpu_big0_s0", "rk8602@42", "rockchip,rk8602"))
                body.append("")
            if big1_block:
                body.append(render_rk860x_node(big1_block, "vdd_cpu_big1_s0", "rk8603@43", "rockchip,rk8603"))
            body.append("};\n")
            sections.append("\n".join(body))

        sections.extend(
            [
                "&cpu_l0 {\n\tcpu-supply = <&vdd_cpu_lit_s0>;\n\tmem-supply = <&vdd_cpu_lit_s0>;\n};\n",
                "&cpu_b0 {\n\tcpu-supply = <&vdd_cpu_big0_s0>;\n\tmem-supply = <&vdd_cpu_big0_s0>;\n};\n",
                "&cpu_b2 {\n\tcpu-supply = <&vdd_cpu_big1_s0>;\n\tmem-supply = <&vdd_cpu_big1_s0>;\n};\n",
                "&gpu {\n\tmali-supply = <&vdd_gpu_s0>;\n\tmem-supply = <&vdd_gpu_mem_s0>;\n\tstatus = \"okay\";\n};\n",
                "&rknpu {\n\trknpu-supply = <&vdd_npu_s0>;\n\tmem-supply = <&vdd_npu_s0>;\n\tstatus = \"okay\";\n};\n",
            ]
        )

    return (
        "// SPDX-License-Identifier: (GPL-2.0+ OR MIT)\n\n"
        "/dts-v1/;\n\n"
        + "\n".join(includes)
        + "\n\n/ {\n"
        + root_body
        + "};\n\n"
        + "\n".join(sections)
    )


def validate_with_dtc(output_path: Path, include_kind: str) -> dict[str, object]:
    dtc = shutil.which("dtc")
    cpp = shutil.which("cpp")
    if not dtc or not cpp:
        missing = []
        if not dtc:
            missing.append("dtc")
        if not cpp:
            missing.append("cpp")
        return {"status": "skipped", "reason": f"missing tools: {', '.join(missing)}"}

    include_root = REPO_ROOT / "dts" / include_kind
    with tempfile.NamedTemporaryFile(
        suffix=".dts"
    ) as preprocessed, tempfile.NamedTemporaryFile(suffix=".dtb") as handle:
        preprocess_command = [
            cpp,
            "-nostdinc",
            "-undef",
            "-x",
            "assembler-with-cpp",
            "-I",
            str(include_root),
            str(output_path),
        ]
        preprocessed_run = subprocess.run(
            preprocess_command, capture_output=True, text=True
        )
        if preprocessed_run.returncode != 0:
            return {
                "status": "failed",
                "command": preprocess_command,
                "stderr": preprocessed_run.stderr.strip(),
                "stdout": preprocessed_run.stdout.strip(),
            }
        Path(preprocessed.name).write_text(preprocessed_run.stdout, encoding="utf-8")
        command = [
            dtc,
            "-I",
            "dts",
            "-O",
            "dtb",
            "-o",
            handle.name,
            preprocessed.name,
        ]
        completed = subprocess.run(command, capture_output=True, text=True)
    if completed.returncode == 0:
        return {"status": "ok"}
    return {
        "status": "failed",
        "command": command,
        "stderr": completed.stderr.strip(),
        "stdout": completed.stdout.strip(),
    }


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Normalize RK3588/RK3588S dumped DTS into a cleaner working DTS."
    )
    parser.add_argument("input", type=Path, help="Input dumped or vendor DTS path")
    parser.add_argument("-o", "--output", type=Path, help="Output DTS path")
    args = parser.parse_args()

    input_path = args.input.resolve()
    dumped_content = input_path.read_text(encoding="utf-8", errors="ignore")
    soc_family = detect_soc_family(dumped_content, None)
    output_path = (
        args.output.resolve()
        if args.output
        else default_output_path(input_path).resolve()
    )
    cleaned_content = build_rk806_rk860x_output(dumped_content, soc_family)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(cleaned_content, encoding="utf-8")
    validation = validate_with_dtc(output_path, "vendor")
    print(
        {
            "input": str(input_path.relative_to(REPO_ROOT)),
            "output": str(output_path.relative_to(REPO_ROOT)),
            "soc_family": soc_family,
            "validation": validation,
        }
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
