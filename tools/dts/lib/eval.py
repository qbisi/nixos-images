from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
import re
from functools import lru_cache

from .parse import iter_overlay_blocks, iter_root_blocks, property_value


IGNORED_NODE_NAMES = {
    "aliases",
    "chosen",
    "clocks",
    "memory",
    "reserved-memory",
    "thermal-zones",
}
IGNORED_PROPERTY_NAMES = {
    "linux,phandle",
    "name",
    "phandle",
}
INTERESTING_PROPERTY_NAMES = {
    "#sound-dai-cells",
    "assigned-clock-parents",
    "assigned-clock-rates",
    "compatible",
    "clock-names",
    "dr_mode",
    "interrupt-parent",
    "interrupts",
    "interrupts-extended",
    "phy-mode",
    "phy-names",
    "phys",
    "pinctrl-names",
    "reg",
    "remote-endpoint",
    "reset-names",
    "resets",
    "status",
}
INTERESTING_PROPERTY_PREFIXES = (
    "assigned-clocks",
    "clock-",
    "gpio",
    "interrupt-",
    "phy-",
    "pinctrl-",
    "reset-",
)
INTERESTING_PROPERTY_SUFFIXES = (
    "-gpios",
    "-gpio",
    "-supply",
)
PHANDLE_LIKE_PROPERTY_NAMES = {
    "clocks",
    "connect",
    "interrupt-parent",
    "interrupts-extended",
    "io-channels",
    "mmc-pwrseq",
    "phys",
    "pinctrl-0",
    "pinctrl-1",
    "pinctrl-2",
    "pwms",
    "remote-endpoint",
    "resets",
}
PHANDLE_LIKE_PROPERTY_SUFFIXES = (
    "-gpios",
    "-gpio",
    "-supply",
)
NODE_HEADER_RE = re.compile(r"^(?:(?:[\w.-]+)\s*:\s*)*(.+)$")
ANGLE_GROUP_RE = re.compile(r"<([^>]+)>")
HEX_TOKEN_RE = re.compile(r"0x[0-9a-fA-F]+")
VENDOR_INPUT_GLOB = "*.dts"


@dataclass(slots=True)
class ParsedNode:
    path: str
    name: str
    properties: dict[str, str] = field(default_factory=dict)


@dataclass(slots=True)
class TreeFacts:
    nodes: dict[str, ParsedNode]
    relevant_nodes: set[str]
    relevant_properties: dict[str, dict[str, str]]


def board_lookup_candidates(repo_root: Path, board_name: str) -> list[Path]:
    key = board_name.removesuffix(".dts")
    return list(_vendor_board_index(repo_root).get(key, ()))


@lru_cache(maxsize=1)
def _vendor_board_index(repo_root: Path) -> dict[str, tuple[Path, ...]]:
    vendor_root = repo_root / "dts" / "vendor"
    index: dict[str, list[Path]] = {}
    for path in sorted(vendor_root.rglob(VENDOR_INPUT_GLOB)):
        key = path.stem
        index.setdefault(key, []).append(path.resolve())
    return {key: tuple(paths) for key, paths in index.items()}


def resolve_vendor_input(repo_root: Path, raw_input: str) -> Path:
    candidate = Path(raw_input)
    if candidate.exists():
        return candidate.resolve()

    matches = board_lookup_candidates(repo_root, raw_input)
    if len(matches) == 1:
        return matches[0]
    if len(matches) > 1:
        joined = ", ".join(str(path.relative_to(repo_root)) for path in matches[:8])
        raise FileNotFoundError(f"Ambiguous board name '{raw_input}'. Matching DTS files: {joined}")
    raise FileNotFoundError(
        f"Input '{raw_input}' does not exist and no matching DTS was found under dts/vendor/**/{Path(raw_input).name}.dts"
    )


def discover_vendor_rk3588_dts(repo_root: Path, detect_soc_family: callable) -> list[Path]:
    base = repo_root / "dts" / "vendor" / "rockchip"
    discovered: list[Path] = []
    for path in sorted(base.glob("*.dts")):
        content = path.read_text(encoding="utf-8", errors="ignore")
        soc_family = detect_soc_family(content)
        if soc_family in {"rk3588", "rk3588s"} and "rockchip,rk3588" in content.lower():
            discovered.append(path.resolve())
    return discovered


def evaluate_restored_dts(
    vendor_compiled_dts: str,
    restored_compiled_dts: str,
    restored_source: str,
    *,
    restored_validation_ok: bool,
    unresolved: list[dict[str, str]] | None = None,
) -> dict[str, object]:
    unresolved = unresolved or []
    if not restored_compiled_dts.strip():
        build_validity = build_validity_score(restored_validation_ok, unresolved)
        delta_correctness = delta_correctness_score(
            restored_source,
            matched_nodes=0,
            missing_nodes=0,
            extra_nodes=0,
        )
        semantic_fidelity = {
            "score": 0,
            "max_score": 40,
            "checks": {
                "node_fidelity_points": 0,
                "property_fidelity_points": 0,
                "matched_node_count": 0,
                "missing_node_count": 0,
                "extra_node_count": 0,
                "matched_property_count": 0,
                "missing_property_count": 0,
                "extra_property_count": 0,
            },
            "reason": "restored DTS did not compile, so merged-tree semantic comparison was skipped",
        }
        return {
            "total_score": build_validity["score"] + delta_correctness["score"] + semantic_fidelity["score"],
            "breakdown": {
                "build_validity": build_validity,
                "delta_correctness": delta_correctness,
                "semantic_fidelity": semantic_fidelity,
            },
            "errors": {
                "missing_nodes": [],
                "extra_nodes": [],
                "mismatched_properties": [],
            },
        }

    vendor_facts = extract_tree_facts(vendor_compiled_dts)
    restored_facts = extract_tree_facts(restored_compiled_dts)

    missing_nodes = sorted(vendor_facts.relevant_nodes - restored_facts.relevant_nodes)
    extra_nodes = sorted(restored_facts.relevant_nodes - vendor_facts.relevant_nodes)

    vendor_props = flatten_properties(vendor_facts.relevant_properties)
    restored_props = flatten_properties(restored_facts.relevant_properties)
    matched_props = sorted(set(vendor_props) & set(restored_props))
    missing_props = sorted(set(vendor_props) - set(restored_props))
    extra_props = sorted(set(restored_props) - set(vendor_props))

    build_validity = build_validity_score(restored_validation_ok, unresolved)
    delta_correctness = delta_correctness_score(
        restored_source,
        matched_nodes=len(vendor_facts.relevant_nodes & restored_facts.relevant_nodes),
        missing_nodes=len(missing_nodes),
        extra_nodes=len(extra_nodes),
    )
    semantic_fidelity = semantic_fidelity_score(
        matched_nodes=len(vendor_facts.relevant_nodes & restored_facts.relevant_nodes),
        missing_nodes=len(missing_nodes),
        extra_nodes=len(extra_nodes),
        matched_props=len(matched_props),
        missing_props=len(missing_props),
        extra_props=len(extra_props),
    )

    return {
        "total_score": build_validity["score"] + delta_correctness["score"] + semantic_fidelity["score"],
        "breakdown": {
            "build_validity": build_validity,
            "delta_correctness": delta_correctness,
            "semantic_fidelity": semantic_fidelity,
        },
        "errors": {
            "missing_nodes": missing_nodes,
            "extra_nodes": extra_nodes,
            "mismatched_properties": format_property_errors(missing_props, extra_props),
        },
    }


def build_validity_score(restored_validation_ok: bool, unresolved: list[dict[str, str]]) -> dict[str, object]:
    compile_points = 10 if restored_validation_ok else 0
    unresolved_points = 10 if not unresolved else 0
    return {
        "score": compile_points + unresolved_points,
        "max_score": 20,
        "checks": {
            "compiles_with_dtc": restored_validation_ok,
            "no_unresolved_references": not unresolved,
        },
        "unresolved": unresolved,
    }


def delta_correctness_score(
    restored_source: str,
    *,
    matched_nodes: int,
    missing_nodes: int,
    extra_nodes: int,
) -> dict[str, object]:
    emitted_ignored_nodes, disabled_blocks = inspect_restored_source(restored_source)
    compared_nodes = matched_nodes + missing_nodes + extra_nodes
    extraction_points = 15
    if compared_nodes > 0:
        extraction_points = round((matched_nodes / compared_nodes) * 15)
    precision_points = 15
    produced_nodes = matched_nodes + extra_nodes
    if produced_nodes > 0:
        precision_points = round((matched_nodes / produced_nodes) * 15)
    hygiene_points = 10 if not emitted_ignored_nodes and not disabled_blocks else 0
    return {
        "score": extraction_points + precision_points + hygiene_points,
        "max_score": 40,
        "checks": {
            "board_level_nodes_correctly_extracted": extraction_points,
            "no_soc_level_nodes_incorrectly_emitted": precision_points,
            "no_disabled_nodes_emitted": not disabled_blocks,
            "no_ignored_nodes_emitted": not emitted_ignored_nodes,
        },
        "errors": {
            "ignored_nodes": emitted_ignored_nodes,
            "disabled_blocks": disabled_blocks,
        },
    }


def semantic_fidelity_score(
    *,
    matched_nodes: int,
    missing_nodes: int,
    extra_nodes: int,
    matched_props: int,
    missing_props: int,
    extra_props: int,
) -> dict[str, object]:
    node_denominator = matched_nodes + missing_nodes + extra_nodes
    property_denominator = matched_props + missing_props + extra_props
    node_points = 20 if node_denominator == 0 else round((matched_nodes / node_denominator) * 20)
    property_points = 20 if property_denominator == 0 else round((matched_props / property_denominator) * 20)
    return {
        "score": node_points + property_points,
        "max_score": 40,
        "checks": {
            "node_fidelity_points": node_points,
            "property_fidelity_points": property_points,
            "matched_node_count": matched_nodes,
            "missing_node_count": missing_nodes,
            "extra_node_count": extra_nodes,
            "matched_property_count": matched_props,
            "missing_property_count": missing_props,
            "extra_property_count": extra_props,
        },
    }


def inspect_restored_source(content: str) -> tuple[list[str], list[str]]:
    ignored_nodes: list[str] = []
    disabled_blocks: list[str] = []
    for block in iter_root_blocks(content):
        name = block_header_name(block)
        if name in IGNORED_NODE_NAMES or name.startswith("opp-table"):
            ignored_nodes.append(name)
        if property_value(block, "status") == '"disabled"':
            disabled_blocks.append(name)
    for target, block in iter_overlay_blocks(content):
        if property_value(block, "status") == '"disabled"':
            disabled_blocks.append(f"&{target}")
    return sorted(set(ignored_nodes)), sorted(set(disabled_blocks))


def extract_tree_facts(content: str) -> TreeFacts:
    nodes = parse_dts_tree(content)
    phandle_map = build_phandle_map(nodes)
    normalized_properties: dict[str, dict[str, str]] = {}

    for path, node in nodes.items():
        if path == "/" or should_ignore_node(node):
            continue
        properties: dict[str, str] = {}
        for name, value in node.properties.items():
            if not is_interesting_property(name):
                continue
            properties[name] = normalize_property_value(name, value, phandle_map)
        normalized_properties[path] = properties

    relevant_nodes = {
        path
        for path, node in nodes.items()
        if path != "/" and not should_ignore_node(node) and is_interesting_node(node, normalized_properties.get(path, {}))
    }
    changed = True
    while changed:
        changed = False
        for path, node in nodes.items():
            if path == "/" or should_ignore_node(node) or path in relevant_nodes:
                continue
            properties = normalized_properties.get(path, {})
            if is_board_device_node(path, properties, relevant_nodes):
                relevant_nodes.add(path)
                changed = True

    relevant_properties = {
        path: normalized_properties[path]
        for path in relevant_nodes
        if normalized_properties.get(path)
    }

    return TreeFacts(nodes=nodes, relevant_nodes=relevant_nodes, relevant_properties=relevant_properties)


def parse_dts_tree(content: str) -> dict[str, ParsedNode]:
    nodes: dict[str, ParsedNode] = {"/": ParsedNode(path="/", name="/")}
    stack = ["/"]
    pending: list[str] = []

    for raw_line in content.splitlines():
        line = strip_line_comment(raw_line).strip()
        if not line:
            continue
        pending.append(line)
        joined = " ".join(pending).strip()

        if joined.endswith("{"):
            header = joined[:-1].strip()
            pending.clear()
            node_name = parse_node_name(header)
            parent = stack[-1]
            if node_name == "/":
                stack = ["/"]
                continue
            path = node_name if parent == "/" else f"{parent}/{node_name}"
            nodes[path] = ParsedNode(path=path, name=node_name)
            stack.append(path)
            continue

        if joined in {"};", "}"}:
            pending.clear()
            if len(stack) > 1:
                stack.pop()
            continue

        if joined.endswith(";"):
            pending.clear()
            prop_name, prop_value = parse_property(joined)
            if prop_name:
                nodes[stack[-1]].properties[prop_name] = prop_value

    return nodes


def build_phandle_map(nodes: dict[str, ParsedNode]) -> dict[str, str]:
    mapping: dict[str, str] = {}
    for path, node in nodes.items():
        for key in ("phandle", "linux,phandle"):
            if key not in node.properties:
                continue
            token = normalize_numeric_token(node.properties[key].strip("<> "))
            if token:
                mapping[token] = path
    return mapping


def flatten_properties(properties: dict[str, dict[str, str]]) -> set[str]:
    flattened: set[str] = set()
    for path, props in properties.items():
        for name, value in props.items():
            flattened.add(f"{path}|{name}|{value}")
    return flattened


def format_property_errors(missing_props: list[str], extra_props: list[str]) -> list[dict[str, str]]:
    errors: list[dict[str, str]] = []
    for value in missing_props:
        path, name, normalized = value.split("|", 2)
        errors.append({"kind": "missing", "path": path, "property": name, "value": normalized})
    for value in extra_props:
        path, name, normalized = value.split("|", 2)
        errors.append({"kind": "extra", "path": path, "property": name, "value": normalized})
    return errors


def should_ignore_node(node: ParsedNode) -> bool:
    if node.name in IGNORED_NODE_NAMES:
        return True
    if "/reserved-memory/" in node.path or "/thermal-zones/" in node.path:
        return True
    if "/opp-table" in node.path or node.name.startswith("opp-table"):
        return True
    if "operating-points-v2" in node.properties:
        return True
    return False


def is_interesting_node(node: ParsedNode, properties: dict[str, str]) -> bool:
    if node.name in {"ports"} or node.name.startswith("endpoint"):
        return True
    if properties.get("status") == '"okay"':
        return True
    if "remote-endpoint" in properties:
        return True
    if has_relevant_delta_properties(properties):
        return True
    return False


def is_board_device_node(path: str, properties: dict[str, str], relevant_nodes: set[str]) -> bool:
    if "compatible" not in properties or "reg" not in properties:
        return False
    parent = parent_path(path)
    if not parent or parent == "/":
        return False
    if parent in relevant_nodes:
        return True
    return parent_name(path).startswith(("i2c@", "spi@", "mdio", "pwm@", "usb@", "pcie@"))


def has_relevant_delta_properties(properties: dict[str, str]) -> bool:
    ignored = {"compatible", "reg", "status"}
    return any(name not in ignored for name in properties)


def is_interesting_property(name: str) -> bool:
    if name in IGNORED_PROPERTY_NAMES:
        return False
    if name in INTERESTING_PROPERTY_NAMES:
        return True
    if any(name.startswith(prefix) for prefix in INTERESTING_PROPERTY_PREFIXES):
        return True
    if any(name.endswith(suffix) for suffix in INTERESTING_PROPERTY_SUFFIXES):
        return True
    return False


def normalize_property_value(name: str, value: str, phandle_map: dict[str, str]) -> str:
    normalized = " ".join(value.split())
    if is_phandle_like_property(name):
        normalized = replace_phandle_tokens(normalized, phandle_map)
    normalized = HEX_TOKEN_RE.sub(lambda match: str(int(match.group(0), 16)), normalized)
    return normalized


def is_phandle_like_property(name: str) -> bool:
    if name in PHANDLE_LIKE_PROPERTY_NAMES:
        return True
    if any(name.endswith(suffix) for suffix in PHANDLE_LIKE_PROPERTY_SUFFIXES):
        return True
    if name.startswith("assigned-clocks"):
        return True
    if name.startswith("pinctrl-"):
        return True
    return False


def replace_phandle_tokens(value: str, phandle_map: dict[str, str]) -> str:
    def rewrite_group(match: re.Match[str]) -> str:
        tokens = match.group(1).split()
        rewritten: list[str] = []
        for token in tokens:
            normalized = normalize_numeric_token(token)
            if normalized in phandle_map:
                rewritten.append(f"&{{{phandle_map[normalized]}}}")
            else:
                rewritten.append(token)
        return "<" + " ".join(rewritten) + ">"

    return ANGLE_GROUP_RE.sub(rewrite_group, value)


def normalize_numeric_token(token: str) -> str:
    value = token.strip().strip("<>").strip()
    if not value:
        return ""
    try:
        return str(int(value, 0))
    except ValueError:
        return value


def strip_line_comment(line: str) -> str:
    return line.split("//", 1)[0]


def parse_node_name(header: str) -> str:
    if header == "/":
        return "/"
    match = NODE_HEADER_RE.match(header)
    if not match:
        return header
    return match.group(1).strip()


def parse_property(statement: str) -> tuple[str, str]:
    body = statement[:-1].strip()
    if "=" not in body:
        return body, "true"
    name, value = body.split("=", 1)
    return name.strip(), value.strip()


def block_header_name(block: str) -> str:
    header = block.split("{", 1)[0].strip()
    return parse_node_name(header)


def parent_path(path: str) -> str | None:
    if "/" not in path:
        return None
    if path.count("/") == 1:
        return "/"
    return path.rsplit("/", 1)[0]


def parent_name(path: str) -> str:
    parent = parent_path(path)
    if not parent or parent == "/":
        return ""
    return parent.rsplit("/", 1)[-1]
