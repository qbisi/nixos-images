#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import tempfile
from pathlib import Path

from lib.converter import (
    default_output_path,
    detect_soc_family,
    infer_mode,
    render_conversion,
)
from lib.validate import compile_dts_to_dtb, decompile_dtb_to_dts, validate_with_dtc


REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_WORK_ROOT = Path("/tmp") / "rk3588-fdtclean"


def display_path(path: Path) -> str:
    try:
        return str(path.relative_to(REPO_ROOT))
    except ValueError:
        return str(path)


def default_tmp_output_path(input_path: Path, mode: str) -> Path:
    default_name = default_output_path(input_path, mode).name
    return DEFAULT_WORK_ROOT / input_path.stem / default_name


def compact_validation(result: dict[str, object]) -> dict[str, object]:
    compact = {"status": result.get("status")}
    if "output" in result:
        compact["output"] = result["output"]
    if result.get("status") == "failed":
        stderr = str(result.get("stderr", "")).strip()
        if stderr:
            compact["stderr_preview"] = "\n".join(stderr.splitlines()[:6])
    if result.get("status") == "skipped" and "reason" in result:
        compact["reason"] = result["reason"]
    return compact


def is_dump_input(input_path: Path, mode: str) -> bool:
    if mode == "dump-cleanup":
        return True
    return (
        "fdtdump" in input_path.parts
        or input_path.name.endswith(".dumped.dts")
        or input_path.name.endswith(".dts.dumped")
    )


def prepare_source_content(input_path: Path, mode: str) -> tuple[str, dict[str, object]]:
    content = input_path.read_text(encoding="utf-8", errors="ignore")
    if mode != "vendor-to-mainline" or is_dump_input(input_path, mode):
        return content, {"kind": "direct"}

    fdtdump_path = REPO_ROOT / "dts" / "fdtdump" / input_path.name

    with tempfile.TemporaryDirectory(prefix="rk3588-fdtclean-") as temp_dir:
        temp_root = Path(temp_dir)
        compiled_dtb = temp_root / f"{input_path.stem}.dtb"
        dumped_dts = temp_root / f"{input_path.stem}.dumped.dts"
        compile_result = compile_dts_to_dtb(REPO_ROOT, input_path, "vendor", compiled_dtb)
        if compile_result.get("status") != "ok":
            if fdtdump_path.exists():
                return fdtdump_path.read_text(encoding="utf-8", errors="ignore"), {
                    "kind": "fdtdump-fallback",
                    "fdtdump": display_path(fdtdump_path),
                    "compile": compact_validation(compile_result),
                }
            return content, {
                "kind": "direct-fallback",
                "compile": compact_validation(compile_result),
            }
        decompile_result = decompile_dtb_to_dts(compiled_dtb, dumped_dts)
        if decompile_result.get("status") != "ok":
            if fdtdump_path.exists():
                return fdtdump_path.read_text(encoding="utf-8", errors="ignore"), {
                    "kind": "fdtdump-fallback",
                    "fdtdump": display_path(fdtdump_path),
                    "compile": compact_validation(compile_result),
                    "decompile": compact_validation(decompile_result),
                }
            return content, {
                "kind": "direct-fallback",
                "compile": compact_validation(compile_result),
                "decompile": compact_validation(decompile_result),
            }
        return dumped_dts.read_text(encoding="utf-8", errors="ignore"), {
            "kind": "compiled-dump",
            "compile": compact_validation(compile_result),
            "decompile": compact_validation(decompile_result),
        }


def convert_dts(
    input_path: Path,
    mode: str | None = None,
    output_path: Path | None = None,
) -> dict[str, object]:
    input_path = input_path.resolve()
    resolved_mode = infer_mode(input_path, mode)
    content, source_preparation = prepare_source_content(input_path, resolved_mode)
    soc_family = detect_soc_family(content)
    resolved_output_path = (
        output_path.resolve()
        if output_path
        else default_tmp_output_path(input_path, resolved_mode).resolve()
    )

    board_model, converted_content = render_conversion(
        content,
        resolved_mode,
        soc_family,
    )

    resolved_output_path.parent.mkdir(parents=True, exist_ok=True)
    resolved_output_path.write_text(converted_content, encoding="utf-8")

    include_kind = "vendor" if resolved_mode == "dump-cleanup" else "mainline"
    validation = validate_with_dtc(REPO_ROOT, resolved_output_path, include_kind)

    unresolved = [{"kind": item.kind, "detail": item.detail} for item in board_model.unresolved]
    return {
        "details": {
            "input": display_path(input_path),
            "mode": resolved_mode,
            "soc_family": soc_family,
            "source_preparation": source_preparation,
            "validation": compact_validation(validation),
            "unresolved": {
                "count": len(unresolved),
                "sample": unresolved[:8],
                "truncated": len(unresolved) > 8,
            },
        },
        "summary": {
            "input": display_path(input_path),
            "cleaned_dts": str(resolved_output_path),
            "mode": resolved_mode,
            "soc_family": soc_family,
            "validation_status": validation.get("status"),
            "unresolved_count": len(unresolved),
        },
    }


def fdtclean(input_path: Path, output_path: Path | None = None) -> dict[str, object]:
    return convert_dts(input_path, mode="dump-cleanup", output_path=output_path)


def migrate_to_mainline(input_path: Path, output_path: Path | None = None) -> dict[str, object]:
    return convert_dts(input_path, mode="vendor-to-mainline", output_path=output_path)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Convert RK3588/RK3588S dumped or vendor DTS into cleaner working DTS."
    )
    parser.add_argument("input", type=Path, help="Input dumped or vendor DTS path")
    parser.add_argument(
        "--mode",
        choices=["dump-cleanup", "vendor-to-mainline"],
        help="Conversion mode. Defaults to inferring from the input path.",
    )
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        help="Output DTS path. Defaults to /tmp/rk3588-fdtclean/<input-stem>/...",
    )
    args = parser.parse_args()

    report = convert_dts(args.input, mode=args.mode, output_path=args.output)

    print(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
