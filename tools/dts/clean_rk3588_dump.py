#!/usr/bin/env python3

from __future__ import annotations

import argparse
from pathlib import Path

from lib.converter import (
    default_output_path,
    detect_soc_family,
    extract_reference_model,
    infer_mode,
    render_conversion,
)
from lib.score import score_models
from lib.validate import validate_with_dtc


REPO_ROOT = Path(__file__).resolve().parents[2]


def display_path(path: Path) -> str:
    try:
        return str(path.relative_to(REPO_ROOT))
    except ValueError:
        return str(path)


def default_reference_path(input_path: Path, mode: str) -> Path | None:
    if mode != "vendor-to-mainline":
        return None
    candidate = REPO_ROOT / "dts" / "mainline" / "rockchip" / input_path.name
    if candidate.exists():
        return candidate
    candidate = REPO_ROOT / "dts" / "mainline" / input_path.name
    if candidate.exists():
        return candidate
    return None


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
    parser.add_argument("-o", "--output", type=Path, help="Output DTS path")
    parser.add_argument(
        "--reference",
        type=Path,
        help="Optional reference DTS used for similarity scoring",
    )
    args = parser.parse_args()

    input_path = args.input.resolve()
    content = input_path.read_text(encoding="utf-8", errors="ignore")
    mode = infer_mode(input_path, args.mode)
    soc_family = detect_soc_family(content)
    output_path = args.output.resolve() if args.output else default_output_path(input_path, mode).resolve()

    board_model, converted_content = render_conversion(content, mode, soc_family)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(converted_content, encoding="utf-8")

    include_kind = "vendor" if mode == "dump-cleanup" else "mainline"
    validation = validate_with_dtc(REPO_ROOT, output_path, include_kind)

    reference_path = args.reference.resolve() if args.reference else default_reference_path(input_path, mode)
    score = None
    if reference_path and reference_path.exists():
        reference_content = reference_path.read_text(encoding="utf-8", errors="ignore")
        reference_model = extract_reference_model(reference_content, "vendor-to-mainline", soc_family)
        score = {
            "reference": str(reference_path.relative_to(REPO_ROOT)),
            "result": score_models(board_model, reference_model),
        }

    print(
        {
            "input": display_path(input_path),
            "output": display_path(output_path),
            "mode": mode,
            "soc_family": soc_family,
            "validation": validation,
            "unresolved": [{"kind": item.kind, "detail": item.detail} for item in board_model.unresolved],
            "score": score,
        }
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
