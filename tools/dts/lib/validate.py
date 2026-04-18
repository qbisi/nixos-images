from __future__ import annotations

import shutil
import subprocess
import tempfile
from pathlib import Path


def build_include_dirs(repo_root: Path, include_kind: str) -> list[Path]:
    include_root = repo_root / "dts" / include_kind
    return [
        include_root,
        include_root / "rockchip",
        include_root / "dt-bindings",
        repo_root / "dts" / "vendor",
        repo_root / "dts" / "vendor" / "rockchip",
        repo_root / "dts" / "vendor" / "dt-bindings",
        repo_root / "dts" / "mainline",
        repo_root / "dts" / "mainline" / "rockchip",
        repo_root / "dts" / "mainline" / "dt-bindings",
    ]


def require_cpp_dtc() -> tuple[str, str] | tuple[None, None]:
    dtc = shutil.which("dtc")
    cpp = shutil.which("cpp")
    if not dtc or not cpp:
        return None, None
    return cpp, dtc


def compile_dts_to_dtb(
    repo_root: Path,
    input_path: Path,
    include_kind: str,
    output_path: Path,
) -> dict[str, object]:
    cpp, dtc = require_cpp_dtc()
    if not dtc or not cpp:
        missing = []
        if not dtc:
            missing.append("dtc")
        if not cpp:
            missing.append("cpp")
        return {"status": "skipped", "reason": f"missing tools: {', '.join(missing)}"}

    include_dirs = build_include_dirs(repo_root, include_kind)
    with tempfile.NamedTemporaryFile(
        suffix=".dts"
    ) as preprocessed:
        preprocess_command = [
            cpp,
            "-nostdinc",
            "-undef",
            "-x",
            "assembler-with-cpp",
        ]
        for include_dir in include_dirs:
            preprocess_command.extend(["-I", str(include_dir)])
        preprocess_command.append(str(input_path))
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
            str(output_path),
            preprocessed.name,
        ]
        completed = subprocess.run(command, capture_output=True, text=True)
    if completed.returncode == 0:
        return {"status": "ok", "output": str(output_path)}
    return {
        "status": "failed",
        "command": command,
        "stderr": completed.stderr.strip(),
        "stdout": completed.stdout.strip(),
    }


def decompile_dtb_to_dts(input_path: Path, output_path: Path) -> dict[str, object]:
    dtc = shutil.which("dtc")
    if not dtc:
        return {"status": "skipped", "reason": "missing tools: dtc"}
    command = [
        dtc,
        "-I",
        "dtb",
        "-O",
        "dts",
        "-o",
        str(output_path),
        str(input_path),
    ]
    completed = subprocess.run(command, capture_output=True, text=True)
    if completed.returncode == 0:
        return {"status": "ok", "output": str(output_path)}
    return {
        "status": "failed",
        "command": command,
        "stderr": completed.stderr.strip(),
        "stdout": completed.stdout.strip(),
    }


def validate_with_dtc(repo_root: Path, output_path: Path, include_kind: str) -> dict[str, object]:
    with tempfile.NamedTemporaryFile(suffix=".dtb") as handle:
        return compile_dts_to_dtb(
            repo_root=repo_root,
            input_path=output_path,
            include_kind=include_kind,
            output_path=Path(handle.name),
        )
