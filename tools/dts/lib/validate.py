from __future__ import annotations

import shutil
import subprocess
import tempfile
from pathlib import Path


def validate_with_dtc(repo_root: Path, output_path: Path, include_kind: str) -> dict[str, object]:
    dtc = shutil.which("dtc")
    cpp = shutil.which("cpp")
    if not dtc or not cpp:
        missing = []
        if not dtc:
            missing.append("dtc")
        if not cpp:
            missing.append("cpp")
        return {"status": "skipped", "reason": f"missing tools: {', '.join(missing)}"}

    include_root = repo_root / "dts" / include_kind
    include_dirs = [
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
    with tempfile.NamedTemporaryFile(
        suffix=".dts"
    ) as preprocessed, tempfile.NamedTemporaryFile(suffix=".dtb") as handle:
        preprocess_command = [
            cpp,
            "-nostdinc",
            "-undef",
            "-x",
            "assembler-with-cpp",
        ]
        for include_dir in include_dirs:
            preprocess_command.extend(["-I", str(include_dir)])
        preprocess_command.append(str(output_path))
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
