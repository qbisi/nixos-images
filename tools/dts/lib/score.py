from __future__ import annotations

from .board_model import BoardModel


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

