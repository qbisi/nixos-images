#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
from pathlib import Path

from lib.converter import detect_soc_family, extract_structural_model, render_conversion
from lib.score import score_models, score_text_similarity
from lib.validate import compile_dts_to_dtb, decompile_dtb_to_dts, validate_with_dtc


REPO_ROOT = Path(__file__).resolve().parents[2]


def display_path(path: Path) -> str:
    try:
        return str(path.relative_to(REPO_ROOT))
    except ValueError:
        return str(path)


def default_work_root() -> Path:
    return Path("/tmp") / "rk3588-dump-cleanup-bench"


def benchmark_one(input_path: Path, work_root: Path, include_kind: str) -> dict[str, object]:
    source_content = input_path.read_text(encoding="utf-8", errors="ignore")
    soc_family = detect_soc_family(source_content)
    stem = input_path.stem
    case_root = work_root / stem
    case_root.mkdir(parents=True, exist_ok=True)

    compiled_dtb = case_root / f"{stem}.compiled.dtb"
    dumped_dts = case_root / f"{stem}.dumped.dts"
    restored_dts = case_root / f"{stem}.restored.dts"

    compile_result = compile_dts_to_dtb(
        repo_root=REPO_ROOT,
        input_path=input_path,
        include_kind=include_kind,
        output_path=compiled_dtb,
    )
    if compile_result["status"] != "ok":
        return {
            "input": display_path(input_path),
            "soc_family": soc_family,
            "compile": compile_result,
        }

    decompile_result = decompile_dtb_to_dts(compiled_dtb, dumped_dts)
    if decompile_result["status"] != "ok":
        return {
            "input": display_path(input_path),
            "soc_family": soc_family,
            "compile": compile_result,
            "decompile": decompile_result,
        }

    dumped_content = dumped_dts.read_text(encoding="utf-8", errors="ignore")
    restored_model, restored_content = render_conversion(
        dumped_content,
        mode="dump-cleanup",
        soc_family=soc_family,
    )
    restored_dts.write_text(restored_content, encoding="utf-8")

    restored_validation = validate_with_dtc(REPO_ROOT, restored_dts, include_kind)
    reference_model = extract_structural_model(source_content, soc_family)
    produced_model = extract_structural_model(restored_content, soc_family)

    return {
        "input": display_path(input_path),
        "soc_family": soc_family,
        "artifacts": {
            "compiled_dtb": str(compiled_dtb),
            "dumped_dts": str(dumped_dts),
            "restored_dts": str(restored_dts),
        },
        "compile": compile_result,
        "decompile": decompile_result,
        "restored_validation": restored_validation,
        "structural_score": score_models(produced_model, reference_model),
        "text_score": score_text_similarity(restored_content, source_content),
        "unresolved": [{"kind": item.kind, "detail": item.detail} for item in restored_model.unresolved],
    }


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Benchmark RK3588 dump-cleanup by round-tripping cleaned DTS through DTB and fdtdump form."
    )
    parser.add_argument(
        "inputs",
        nargs="+",
        type=Path,
        help="Cleaned DTS inputs, typically from dts/vendor/",
    )
    parser.add_argument(
        "--include-kind",
        default="vendor",
        choices=["vendor", "mainline"],
        help="Include tree used to compile the cleaned DTS source.",
    )
    parser.add_argument(
        "--work-root",
        type=Path,
        default=default_work_root(),
        help="Directory for generated DTB, dumped DTS, and restored DTS artifacts.",
    )
    args = parser.parse_args()

    results = []
    for input_path in args.inputs:
        results.append(benchmark_one(input_path.resolve(), args.work_root.resolve(), args.include_kind))

    successful = [item for item in results if item.get("structural_score")]
    aggregate = None
    if successful:
        aggregate = {
            "cases": len(successful),
            "avg_structural_score": round(
                sum(item["structural_score"]["score"] for item in successful) / len(successful), 2
            ),
            "avg_text_score": round(
                sum(item["text_score"]["score"] for item in successful) / len(successful), 2
            ),
        }

    print(json.dumps({"results": results, "aggregate": aggregate}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
