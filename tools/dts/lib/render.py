from __future__ import annotations

from .board_model import BoardModel, NodeFact, OverlayFact


def _sort_nodes(nodes: list[NodeFact]) -> list[NodeFact]:
    return sorted(nodes, key=lambda item: (item.category, item.name))


def _sort_overlays(overlays: list[OverlayFact]) -> list[OverlayFact]:
    return sorted(overlays, key=lambda item: (item.category, item.target))


def render_board_model(model: BoardModel) -> str:
    parts = ["// SPDX-License-Identifier: (GPL-2.0+ OR MIT)\n", "/dts-v1/;\n"]
    if model.includes:
        parts.append("")
        for include in model.includes:
            parts.append(f"#include {include}\n")

    parts.append("\n/ {\n")
    parts.append(f'\tmodel = "{model.model}";\n')
    if model.compatibles:
        compatible_text = ", ".join(f'"{item}"' for item in model.compatibles)
        parts.append(f"\tcompatible = {compatible_text};\n")

    if model.aliases:
        parts.append("\n\taliases {\n")
        for alias, target in sorted(model.aliases.items()):
            parts.append(f"\t\t{alias} = <&{target}>;\n")
        parts.append("\t};\n")

    for node in _sort_nodes(model.root_nodes):
        parts.append("\n")
        parts.append(indent_block(node.block.rstrip(), 1))
        parts.append("\n")

    parts.append("};\n")

    for overlay in _sort_overlays(model.overlays):
        parts.append("\n")
        parts.append(overlay.block.rstrip())
        parts.append("\n")

    return "".join(parts)


def indent_block(block: str, depth: int) -> str:
    prefix = "\t" * depth
    lines = block.splitlines()
    return "\n".join(f"{prefix}{line}" if line else "" for line in lines)

