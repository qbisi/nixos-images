#!/usr/bin/env python3

from __future__ import annotations

import argparse
from pathlib import Path

from lib.converter import (
    default_output_path,
    detect_soc_family,
    infer_mode,
    render_conversion,
)
from lib.validate import validate_with_dtc


REPO_ROOT = Path(__file__).resolve().parents[2]


def display_path(path: Path) -> str:
    try:
        return str(path.relative_to(REPO_ROOT))
    except ValueError:
        return str(path)
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
    args = parser.parse_args()

    input_path = args.input.resolve()
    content = input_path.read_text(encoding="utf-8", errors="ignore")
    mode = infer_mode(input_path, args.mode)
    soc_family = detect_soc_family(content)
    output_path = args.output.resolve() if args.output else default_output_path(input_path, mode).resolve()

    board_model, converted_content = render_conversion(
        content,
        mode,
        soc_family,
    )

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(converted_content, encoding="utf-8")

    include_kind = "vendor" if mode == "dump-cleanup" else "mainline"
    validation = validate_with_dtc(REPO_ROOT, output_path, include_kind)

    print(
        {
            "input": display_path(input_path),
            "output": display_path(output_path),
            "mode": mode,
            "soc_family": soc_family,
            "validation": validation,
            "unresolved": [{"kind": item.kind, "detail": item.detail} for item in board_model.unresolved],
        }
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
