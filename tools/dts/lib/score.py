from __future__ import annotations

import re
from difflib import SequenceMatcher

from .board_model import BoardModel
from .parse import iter_overlay_blocks, iter_root_blocks


def score_models(produced: BoardModel, reference: BoardModel) -> dict[str, object]:
    produced_root = {node.name for node in produced.root_nodes}
    reference_root = {node.name for node in reference.root_nodes}
    produced_overlays = {overlay.target for overlay in produced.overlays}
    reference_overlays = {overlay.target for overlay in reference.overlays}

    scores = {
        "model_match": int(produced.model == reference.model),
        "compatibles_overlap": sorted(set(produced.compatibles) & set(reference.compatibles)),
        "missing_root_nodes": sorted(reference_root - produced_root),
        "extra_root_nodes": sorted(produced_root - reference_root),
        "missing_overlays": sorted(reference_overlays - produced_overlays),
        "extra_overlays": sorted(produced_overlays - reference_overlays),
    }
    total = 0
    total += 20 if scores["model_match"] else 0
    total += min(len(scores["compatibles_overlap"]) * 10, 30)
    total += max(0, 25 - len(scores["missing_root_nodes"]) * 5)
    total += max(0, 25 - len(scores["missing_overlays"]) * 3)
    scores["score"] = total
    return scores


def score_text_similarity(produced_text: str, reference_text: str) -> dict[str, object]:
    produced_lines = [line.rstrip() for line in produced_text.splitlines() if line.strip()]
    reference_lines = [line.rstrip() for line in reference_text.splitlines() if line.strip()]
    produced_set = set(produced_lines)
    reference_set = set(reference_lines)
    overlap = produced_set & reference_set
    missing = reference_set - produced_set
    extra = produced_set - reference_set
    ratio = SequenceMatcher(None, "\n".join(produced_lines), "\n".join(reference_lines)).ratio()
    return {
        "line_ratio": round(ratio, 4),
        "shared_line_count": len(overlap),
        "missing_line_count": len(missing),
        "extra_line_count": len(extra),
        "score": round(ratio * 100, 2),
    }


def score_dts_sources(
    produced_text: str,
    reference_text: str,
    *,
    include_details: bool = False,
) -> dict[str, object]:
    produced_nodes = extract_shallow_nodes(produced_text)
    reference_nodes = extract_shallow_nodes(reference_text)
    matched = sorted(set(produced_nodes) & set(reference_nodes))
    missing = sorted(set(reference_nodes) - set(produced_nodes))
    extra = sorted(set(produced_nodes) - set(reference_nodes))
    denominator = len(reference_nodes) + len(extra)
    score = 0.0
    if denominator > 0:
        score = round((len(matched) / denominator) * 100, 2)
    exact_match = produced_nodes == reference_nodes
    result = {
        "unit": "node",
        "matched_node_count": len(matched),
        "missing_node_count": len(missing),
        "extra_node_count": len(extra),
        "reference_node_count": len(reference_nodes),
        "matched_line_count": len(matched),
        "missing_line_count": len(missing),
        "extra_line_count": len(extra),
        "reference_line_count": len(reference_nodes),
        "exact_match": exact_match,
        "score": 100.0 if exact_match else score,
    }
    if include_details:
        result["matched_nodes"] = matched
        result["missing_nodes"] = missing
        result["extra_nodes"] = extra
        result["missing_lines"] = missing
        result["extra_lines"] = extra
    return result


def normalize_dts_lines(text: str) -> list[str]:
    normalized: list[str] = []
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line:
            continue
        normalized.append(" ".join(line.split()))
    return normalized


def extract_shallow_nodes(text: str) -> list[str]:
    nodes: list[str] = []
    for block in iter_root_blocks(text):
        nodes.append(f"root:{shallow_block_signature(block)}")
    for target, block in iter_overlay_blocks(text):
        nodes.append(f"overlay:{target}:{shallow_block_signature(block)}")
    return nodes


def shallow_block_signature(block: str) -> str:
    header = normalize_inline_whitespace(block_header(block))
    statements = sorted(statement for statement in direct_property_statements(block) if statement)
    body = "|".join(statements)
    return f"{header}|{body}"


def block_header(block: str) -> str:
    brace_index = block.find("{")
    if brace_index == -1:
        return block.strip()
    return strip_comments(block[:brace_index]).strip()


def direct_property_statements(block: str) -> list[str]:
    brace_index = block.find("{")
    end_index = block.rfind("}")
    if brace_index == -1 or end_index == -1 or end_index <= brace_index:
        return []
    inner = block[brace_index + 1 : end_index]
    statements: list[str] = []
    current: list[str] = []
    depth = 1

    for char in inner:
        if depth == 1:
            if char == "{":
                current.clear()
            else:
                current.append(char)
                if char == ";":
                    statement = normalize_statement("".join(current))
                    if statement:
                        statements.append(statement)
                    current.clear()
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 1:
                current.clear()
    return statements


def normalize_inline_whitespace(text: str) -> str:
    return " ".join(text.split())


def normalize_statement(text: str) -> str:
    statement = normalize_inline_whitespace(strip_comments(text).strip())
    statement = re.sub(r"\s*=\s*", " = ", statement)
    statement = re.sub(r">\s*,\s*<", " ", statement)
    statement = normalize_numeric_literals(statement)
    if not statement or statement == ";":
        return ""
    return statement


def strip_comments(text: str) -> str:
    return re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)


def normalize_numeric_literals(text: str) -> str:
    def replace(match: re.Match[str]) -> str:
        token = match.group(0)
        if token.lower().startswith("0x"):
            try:
                return str(int(token, 16))
            except ValueError:
                return token
        return token

    return re.sub(r"\b0x[0-9a-fA-F]+\b", replace, text)
