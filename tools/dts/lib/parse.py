from __future__ import annotations

import re


COMPATIBLE_ALL_RE = re.compile(r'"([^"]+)"')
INCLUDE_RE = re.compile(r'^\s*#include\s+([<"][^>"]+[>"])', re.MULTILINE)
MODEL_RE = re.compile(r'model\s*=\s*"([^"]+)";')
ALIAS_RE = re.compile(r"^\s*([\w]+)\s*=\s*<&([\w]+)>;", re.MULTILINE)
PROPERTY_RE_TEMPLATE = r"^\s*{name}\s*=\s*([^;]+);"
BOOL_RE_TEMPLATE = r"^\s*{name}\s*;"


def detect_soc_family(content: str, override: str | None = None) -> str:
    if override:
        return override
    lowered = content.lower()
    if "rockchip,rk3588s" in lowered or 'rk3588s.dtsi' in lowered:
        return "rk3588s"
    return "rk3588"


def find_compatible_list(content: str) -> list[str]:
    match = re.search(r"compatible\s*=\s*([^;]+);", content)
    if not match:
        return []
    return COMPATIBLE_ALL_RE.findall(match.group(1))


def find_model(content: str, default: str) -> str:
    match = MODEL_RE.search(content)
    if not match:
        return default
    return match.group(1)


def find_includes(content: str) -> list[str]:
    return [match.group(1) for match in INCLUDE_RE.finditer(content)]


def property_value(block: str, name: str) -> str | None:
    match = re.search(PROPERTY_RE_TEMPLATE.format(name=re.escape(name)), block, re.MULTILINE)
    if not match:
        return None
    return match.group(1).strip()


def has_property(block: str, name: str) -> bool:
    return re.search(BOOL_RE_TEMPLATE.format(name=re.escape(name)), block, re.MULTILINE) is not None


def extract_block(content: str, node_name: str) -> str | None:
    match = re.search(rf"^\s*{re.escape(node_name)}\s*(?::\s*[\w@,\-]+)?\s*\{{", content, re.MULTILINE)
    if not match:
        return None
    return extract_block_from_index(content, match.start())


def extract_block_from_index(content: str, start: int) -> str | None:
    brace_index = content.find("{", start)
    if brace_index == -1:
        return None
    depth = 0
    for index in range(brace_index, len(content)):
        char = content[index]
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                end = index + 1
                if end < len(content) and content[end] == ";":
                    end += 1
                while end < len(content) and content[end] == "\n":
                    end += 1
                return content[start:end]
    return None


def iter_root_blocks(content: str) -> list[str]:
    root_match = re.search(r"^\s*/\s*\{", content, re.MULTILINE)
    if not root_match:
        return []
    root_block = extract_block_from_index(content, root_match.start())
    if not root_block:
        return []

    blocks: list[str] = []
    depth = 0
    block_start: int | None = None
    start_index = root_block.find("{") + 1
    index = start_index
    while index < len(root_block):
        char = root_block[index]
        if char == "{":
            if depth == 0:
                line_start = root_block.rfind("\n", start_index, index) + 1
                if line_start < 0:
                    line_start = start_index
                while line_start < index and root_block[line_start] in " \t":
                    line_start += 1
                block_start = line_start
            depth += 1
        elif char == "}":
            if depth > 0:
                depth -= 1
                if depth == 0 and block_start is not None:
                    end = index + 1
                    if end < len(root_block) and root_block[end] == ";":
                        end += 1
                    while end < len(root_block) and root_block[end] == "\n":
                        end += 1
                    blocks.append(root_block[block_start:end].strip() + "\n")
                    block_start = None
        index += 1
    return blocks


def iter_overlay_blocks(content: str) -> list[tuple[str, str]]:
    overlays: list[tuple[str, str]] = []
    for match in re.finditer(r"^\s*&([\w]+)\s*\{", content, re.MULTILINE):
        target = match.group(1)
        block = extract_block_from_index(content, match.start())
        if block:
            overlays.append((target, block.strip() + "\n"))
    return overlays


def parse_aliases(content: str) -> dict[str, str]:
    aliases_block = extract_block(content, "aliases")
    if not aliases_block:
        return {}
    return {match.group(1): match.group(2) for match in ALIAS_RE.finditer(aliases_block)}
