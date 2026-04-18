#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
from pathlib import Path

from lib.converter import detect_soc_family, render_conversion
from lib.score import score_dts_sources
from lib.validate import compile_dts_to_dtb, decompile_dtb_to_dts


REPO_ROOT = Path(__file__).resolve().parents[2]


def display_path(path: Path) -> str:
    try:
        return str(path.relative_to(REPO_ROOT))
    except ValueError:
        return str(path)


def default_work_root() -> Path:
    return Path("/tmp") / "rk3588-dump-cleanup-bench"


def resolve_input_path(path: Path) -> Path:
    if path.exists():
        return path.resolve()

    raw = str(path)
    candidates: list[Path] = []
    vendor_root = REPO_ROOT / "dts" / "vendor"

    if raw.endswith(".dts"):
        patterns = [f"**/{Path(raw).name}"]
    else:
        patterns = [f"**/{raw}.dts", f"**/{Path(raw).name}.dts"]

    seen: set[Path] = set()
    for pattern in patterns:
        for candidate in vendor_root.glob(pattern):
            resolved = candidate.resolve()
            if resolved not in seen:
                seen.add(resolved)
                candidates.append(resolved)

    if len(candidates) == 1:
        return candidates[0]
    if len(candidates) > 1:
        joined = ", ".join(str(candidate.relative_to(REPO_ROOT)) for candidate in candidates[:8])
        raise FileNotFoundError(
            f"Ambiguous input '{path}'. Matching vendor DTS files: {joined}"
        )
    raise FileNotFoundError(f"Input '{path}' does not exist and no matching DTS was found under dts/vendor/")


def discover_vendor_rk3588_dts() -> list[Path]:
    base = REPO_ROOT / "dts" / "vendor" / "rockchip"
    discovered: list[Path] = []
    for path in sorted(base.glob("*.dts")):
        content = path.read_text(encoding="utf-8", errors="ignore")
        soc_family = detect_soc_family(content)
        if soc_family in {"rk3588", "rk3588s"} and "rockchip,rk3588" in content.lower():
            discovered.append(path)
    return discovered


def benchmark_one(
    input_path: Path,
    work_root: Path,
    include_kind: str,
    *,
    include_score_details: bool = False,
) -> dict[str, object]:
    source_content = input_path.read_text(encoding="utf-8", errors="ignore")
    soc_family = detect_soc_family(source_content)
    stem = input_path.stem
    case_root = work_root / stem
    case_root.mkdir(parents=True, exist_ok=True)

    compiled_dtb = case_root / f"{stem}.compiled.dtb"
    dumped_dts = case_root / f"{stem}.dumped.dts"
    restored_dts = case_root / f"{stem}.restored.dts"
    restored_compiled_dtb = case_root / f"{stem}.restored.compiled.dtb"
    restored_compiled_dumped_dts = case_root / f"{stem}.restored.compiled.dumped.dts"

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
    restored_validation = {
        **restored_compile,
        "reused_from": "restored_compile",
    }
    restored_decompile: dict[str, object] | None = None
    effective_score: dict[str, object] | None = None
    if restored_compile["status"] == "ok":
        restored_decompile = decompile_dtb_to_dts(restored_compiled_dtb, restored_compiled_dumped_dts)
        if restored_decompile["status"] == "ok":
            reference_compiled_form = dumped_dts.read_text(encoding="utf-8", errors="ignore")
            restored_compiled_form = restored_compiled_dumped_dts.read_text(encoding="utf-8", errors="ignore")
            effective_score = score_dts_sources(
                restored_compiled_form,
                reference_compiled_form,
                include_details=include_score_details,
            )

    return {
        "input": display_path(input_path),
        "soc_family": soc_family,
        "artifacts": {
            "compiled_dtb": str(compiled_dtb),
            "dumped_dts": str(dumped_dts),
            "restored_dts": str(restored_dts),
            "restored_compiled_dtb": str(restored_compiled_dtb),
            "restored_compiled_dumped_dts": str(restored_compiled_dumped_dts),
        },
        "compile": compile_result,
        "decompile": decompile_result,
        "restored_validation": restored_validation,
        "restored_compile": restored_compile,
        "restored_decompile": restored_decompile,
        "source_score": score_dts_sources(
            restored_content,
            source_content,
            include_details=include_score_details,
        ),
        "effective_score": effective_score,
        "unresolved": [{"kind": item.kind, "detail": item.detail} for item in restored_model.unresolved],
    }


def summarize_results(results: list[dict[str, object]]) -> dict[str, object] | None:
    successful = [item for item in results if item.get("source_score")]
    if not successful:
        return None

    def metric_value(item: dict[str, object], metric: str) -> float:
        return float(item[metric]["score"])  # type: ignore[index]

    source_sorted = sorted(successful, key=lambda item: (metric_value(item, "source_score"), item["input"]))
    effective_successful = [item for item in successful if item.get("effective_score")]
    effective_sorted = (
        sorted(effective_successful, key=lambda item: (metric_value(item, "effective_score"), item["input"]))
        if effective_successful
        else []
    )

    failed_compile = [item["input"] for item in results if item.get("compile", {}).get("status") != "ok"]
    failed_decompile = [
        item["input"]
        for item in results
        if item.get("compile", {}).get("status") == "ok" and item.get("decompile", {}).get("status") != "ok"
    ]
    failed_restore_validation = [
        item["input"]
        for item in successful
        if item.get("restored_validation", {}).get("status") != "ok"
    ]
    failed_restored_compile = [
        item["input"]
        for item in successful
        if item.get("restored_compile", {}).get("status") != "ok"
    ]
    failed_restored_decompile = [
        item["input"]
        for item in successful
        if item.get("restored_compile", {}).get("status") == "ok"
        and item.get("restored_decompile", {}).get("status") != "ok"
    ]

    summary = {
        "cases": len(results),
        "successful_cases": len(successful),
        "failed_compile_cases": len(failed_compile),
        "failed_decompile_cases": len(failed_decompile),
        "failed_restore_validation_cases": len(failed_restore_validation),
        "failed_restored_compile_cases": len(failed_restored_compile),
        "failed_restored_decompile_cases": len(failed_restored_decompile),
        "avg_source_score": round(
            sum(metric_value(item, "source_score") for item in successful) / len(successful), 2
        ),
        "best_source": {
            "input": source_sorted[-1]["input"],
            "score": metric_value(source_sorted[-1], "source_score"),
        },
        "min_source": {
            "input": source_sorted[0]["input"],
            "score": metric_value(source_sorted[0], "source_score"),
        },
        "failed_compile_inputs": failed_compile,
        "failed_decompile_inputs": failed_decompile,
        "failed_restore_validation_inputs": failed_restore_validation,
    }
    if effective_successful:
        summary.update(
            {
                "avg_effective_score": round(
                    sum(metric_value(item, "effective_score") for item in effective_successful)
                    / len(effective_successful),
                    2,
                ),
                "best_effective": {
                    "input": effective_sorted[-1]["input"],
                    "score": metric_value(effective_sorted[-1], "effective_score"),
                },
                "min_effective": {
                    "input": effective_sorted[0]["input"],
                    "score": metric_value(effective_sorted[0], "effective_score"),
                },
                "failed_restored_compile_inputs": failed_restored_compile,
                "failed_restored_decompile_inputs": failed_restored_decompile,
            }
        )
    return summary


def format_output(results: list[dict[str, object]], aggregate: dict[str, object] | None) -> dict[str, object]:
    if len(results) == 1:
        if aggregate is None:
            return {"results": results, "aggregate": None}
        single_aggregate = {
            "cases": aggregate["cases"],
            "successful_cases": aggregate["successful_cases"],
            "failed_compile_cases": aggregate["failed_compile_cases"],
            "failed_decompile_cases": aggregate["failed_decompile_cases"],
            "failed_restore_validation_cases": aggregate["failed_restore_validation_cases"],
            "failed_restored_compile_cases": aggregate["failed_restored_compile_cases"],
            "failed_restored_decompile_cases": aggregate["failed_restored_decompile_cases"],
        }
        return {"results": results, "aggregate": single_aggregate}
    return {"results": results, "aggregate": aggregate}


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Benchmark RK3588 dump-cleanup by round-tripping cleaned DTS through DTB and fdtdump form."
    )
    parser.add_argument(
        "inputs",
        nargs="*",
        type=Path,
        help="Cleaned DTS inputs. If omitted with --vendor-rockchip-all, the script discovers all RK3588/RK3588S DTS files under dts/vendor/rockchip.",
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
    parser.add_argument(
        "--vendor-rockchip-all",
        action="store_true",
        help="Benchmark all RK3588/RK3588S DTS files under dts/vendor/rockchip.",
    )
    parser.add_argument(
        "--score-details",
        action="store_true",
        help="Include per-score missing/extra node details in the JSON output.",
    )
    args = parser.parse_args()

    try:
        inputs = [resolve_input_path(path) for path in args.inputs]
    except FileNotFoundError as exc:
        parser.error(str(exc))
        return 2
    if args.vendor_rockchip_all:
        inputs = discover_vendor_rk3588_dts()
    if not inputs:
        parser.error("Provide one or more input DTS files, or use --vendor-rockchip-all.")

    results = []
    for input_path in inputs:
        results.append(
            benchmark_one(
                input_path,
                args.work_root.resolve(),
                args.include_kind,
                include_score_details=args.score_details,
            )
        )

    aggregate = summarize_results(results)

    print(json.dumps(format_output(results, aggregate), indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
