from __future__ import annotations

from dataclasses import dataclass, field


@dataclass(slots=True)
class NodeFact:
    name: str
    block: str
    label: str | None = None
    category: str = "generic"
    origin: str = "input"


@dataclass(slots=True)
class OverlayFact:
    target: str
    block: str
    category: str = "generic"
    enabled: bool = False


@dataclass(slots=True)
class UnresolvedFact:
    kind: str
    detail: str


@dataclass(slots=True)
class BoardModel:
    source_kind: str
    soc: str
    model: str
    compatibles: list[str]
    includes: list[str] = field(default_factory=list)
    aliases: dict[str, str] = field(default_factory=dict)
    root_nodes: list[NodeFact] = field(default_factory=list)
    overlays: list[OverlayFact] = field(default_factory=list)
    unresolved: list[UnresolvedFact] = field(default_factory=list)

