#!/usr/bin/env python3
"""
Check which vendor RK3588 DTS files have compile errors in the restored DTS.
This helps prioritize which models need fixing for improved dump-cleanup scores.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

from lib.converter import detect_soc_family
from lib.score import discover_vendor_rk3588_dts
from benchmark import benchmark_one, default_work_root


REPO_ROOT = Path(__file__).resolve().parents[2]


def main() -> int:
    work_root = default_work_root()

    # Discover all vendor RK3588 DTS files
    vendor_dts_files = discover_vendor_rk3588_dts(REPO_ROOT, detect_soc_family)

    print(f"Found {len(vendor_dts_files)} vendor RK3588 DTS files")
    print("Running benchmark on all files...\n")

    compile_errors = []
    decompile_errors = []
    restored_compile_errors = []
    successful = []

    for idx, input_path in enumerate(vendor_dts_files, 1):
        board_name = input_path.stem
        print(
            f"[{idx}/{len(vendor_dts_files)}] Testing {board_name}...",
            end=" ",
            flush=True,
        )

        try:
            result = benchmark_one(input_path, work_root.resolve(), "vendor")

            # Check for original compile error
            if result.get("compile", {}).get("status") != "ok":
                compile_errors.append(
                    (board_name, result.get("compile", {}).get("stderr", "")[:200])
                )
                print("❌ COMPILE ERROR")
                continue

            # Check for decompile error
            if result.get("decompile", {}).get("status") != "ok":
                decompile_errors.append(
                    (board_name, result.get("decompile", {}).get("stderr", "")[:200])
                )
                print("❌ DECOMPILE ERROR")
                continue

            # Check for restored compile error (THIS IS THE KEY ONE)
            if result.get("restored_validation", {}).get("status") != "ok":
                stderr = result.get("restored_validation", {}).get("stderr", "")
                restored_compile_errors.append((board_name, stderr[:500]))
                print("❌ RESTORED COMPILE ERROR")
                continue

            # If we get here, it compiled successfully
            score = result.get("evaluation", {}).get("total_score", "N/A")
            print(f"✓ Score: {score}")
            successful.append((board_name, score))

        except Exception as e:
            print(f"⚠ EXCEPTION: {str(e)[:100]}")

    # Print summary
    print("\n" + "=" * 70)
    print("SUMMARY")
    print("=" * 70)

    print(f"\n✓ SUCCESSFUL (restored DTS compiles): {len(successful)}")
    if successful:
        for board_name, score in sorted(successful)[:10]:
            print(f"  - {board_name}: {score}")
        if len(successful) > 10:
            print(f"  ... and {len(successful) - 10} more")

    print(f"\n❌ RESTORED COMPILE ERRORS: {len(restored_compile_errors)}")
    if restored_compile_errors:
        for board_name, stderr in sorted(restored_compile_errors):
            print(f"  - {board_name}")
            if stderr.strip():
                # Show first few lines of error
                error_preview = "\n".join(stderr.split("\n")[:3])
                for line in error_preview.split("\n"):
                    print(f"    {line}")

    print(f"\n❌ ORIGINAL COMPILE ERRORS: {len(compile_errors)}")
    if compile_errors:
        for board_name, stderr in sorted(compile_errors)[:5]:
            print(f"  - {board_name}")

    print(f"\n❌ DECOMPILE ERRORS: {len(decompile_errors)}")
    if decompile_errors:
        for board_name, stderr in sorted(decompile_errors)[:5]:
            print(f"  - {board_name}")

    print("\n" + "=" * 70)
    print(f"Total: {len(vendor_dts_files)} files")
    print(f"  - {len(successful)} successful")
    print(f"  - {len(restored_compile_errors)} with restored compile errors")
    print(f"  - {len(compile_errors)} with original compile errors")
    print(f"  - {len(decompile_errors)} with decompile errors")
    print("=" * 70)

    # Return exit code based on whether there are restored compile errors
    return 1 if restored_compile_errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
