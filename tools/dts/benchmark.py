#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
from pathlib import Path

from lib.converter import detect_soc_family, render_conversion
from lib.score import discover_vendor_rk3588_dts, evaluate_restored_dts, resolve_vendor_input
from lib.validate import compile_dts_to_dtb, decompile_dtb_to_dts


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
    restored_compiled_dtb = case_root / f"{stem}.restored.compiled.dtb"
    restored_compiled_dts = case_root / f"{stem}.restored.compiled.dts"

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

    restored_compile = compile_dts_to_dtb(
        repo_root=REPO_ROOT,
        input_path=restored_dts,
        include_kind=include_kind,
        output_path=restored_compiled_dtb,
    )

    restored_decompile: dict[str, object] | None = None
    restored_compiled_content = ""
    if restored_compile["status"] == "ok":
        restored_decompile = decompile_dtb_to_dts(restored_compiled_dtb, restored_compiled_dts)
        if restored_decompile["status"] == "ok":
            restored_compiled_content = restored_compiled_dts.read_text(encoding="utf-8", errors="ignore")

    evaluation = evaluate_restored_dts(
        vendor_compiled_dts=dumped_content,
        restored_compiled_dts=restored_compiled_content,
        restored_source=restored_content,
        restored_validation_ok=restored_compile["status"] == "ok",
        unresolved=[{"kind": item.kind, "detail": item.detail} for item in restored_model.unresolved],
    )

    return {
        "input": display_path(input_path),
        "soc_family": soc_family,
        "artifacts": {
            "compiled_dtb": str(compiled_dtb),
            "dumped_dts": str(dumped_dts),
            "restored_dts": str(restored_dts),
            "restored_compiled_dtb": str(restored_compiled_dtb),
            "restored_compiled_dts": str(restored_compiled_dts),
        },
        "compile": compile_result,
        "decompile": decompile_result,
        "restored_validation": restored_compile,
        "restored_decompile": restored_decompile,
        "unresolved": [{"kind": item.kind, "detail": item.detail} for item in restored_model.unresolved],
        "evaluation": evaluation,
    }


def summarize_results(results: list[dict[str, object]]) -> dict[str, object] | None:
    successful = [item for item in results if item.get("evaluation")]
    if not successful:
        return None

    scores = [int(item["evaluation"]["total_score"]) for item in successful]  # type: ignore[index]
    sorted_results = sorted(
        successful,
        key=lambda item: (int(item["evaluation"]["total_score"]), item["input"]),  # type: ignore[index]
    )

    failed_compile = [item["input"] for item in results if item.get("compile", {}).get("status") != "ok"]
    failed_decompile = [
        item["input"]
        for item in results
        if item.get("compile", {}).get("status") == "ok" and item.get("decompile", {}).get("status") != "ok"
    ]
    failed_restore_compile = [
        item["input"]
        for item in results
        if item.get("restored_validation", {}).get("status") != "ok"
    ]
    failed_restore_decompile = [
        item["input"]
        for item in results
        if item.get("restored_validation", {}).get("status") == "ok"
        and item.get("restored_decompile", {}).get("status") != "ok"
    ]

    return {
        "cases": len(results),
        "successful_cases": len(successful),
        "avg_total_score": round(sum(scores) / len(scores), 2),
        "best_case": {
            "input": sorted_results[-1]["input"],
            "score": sorted_results[-1]["evaluation"]["total_score"],  # type: ignore[index]
        },
        "worst_case": {
            "input": sorted_results[0]["input"],
            "score": sorted_results[0]["evaluation"]["total_score"],  # type: ignore[index]
        },
        "failed_compile_cases": len(failed_compile),
        "failed_decompile_cases": len(failed_decompile),
        "failed_restore_compile_cases": len(failed_restore_compile),
        "failed_restore_decompile_cases": len(failed_restore_decompile),
        "failed_compile_inputs": failed_compile,
        "failed_decompile_inputs": failed_decompile,
        "failed_restore_compile_inputs": failed_restore_compile,
        "failed_restore_decompile_inputs": failed_restore_decompile,
    }


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Benchmark RK3588 dump cleanup using score.py with the EVAL.md contract."
    )
    parser.add_argument(
        "inputs",
        nargs="*",
        help="Board names or DTS paths. Board names resolve as dts/vendor/**/$board_name.dts.",
    )
    parser.add_argument(
        "--include-kind",
        default="vendor",
        choices=["vendor", "mainline"],
        help="Include tree used to compile both vendor and restored DTS sources.",
    )
    parser.add_argument(
        "--work-root",
        type=Path,
        default=default_work_root(),
        help="Directory for generated DTB, dumped DTS, restored DTS, and compiled restored DTS artifacts.",
    )
    parser.add_argument(
        "--vendor-rockchip-all",
        action="store_true",
        help="Benchmark all RK3588/RK3588S DTS files under dts/vendor/rockchip.",
    )
    args = parser.parse_args()

    try:
        inputs = [resolve_vendor_input(REPO_ROOT, value) for value in args.inputs]
    except FileNotFoundError as exc:
        parser.error(str(exc))
        return 2

    if args.vendor_rockchip_all:
        inputs = discover_vendor_rk3588_dts(REPO_ROOT, detect_soc_family)
    if not inputs:
        parser.error("Provide one or more board names or DTS paths, or use --vendor-rockchip-all.")

    results = [benchmark_one(input_path, args.work_root.resolve(), args.include_kind) for input_path in inputs]
    print(json.dumps({"results": results, "aggregate": summarize_results(results)}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
