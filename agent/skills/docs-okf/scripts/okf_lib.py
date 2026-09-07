#!/usr/bin/env python3
# OKF 共享库：frontmatter、type 映射、concept 路径；细则见 /docs-okf 与 agent/knowledge/naming-conventions.md §OKF

from __future__ import annotations

import re
from pathlib import Path
from typing import Any, Dict, Iterator, List, Optional, Tuple

OKF_RESERVED_NAMES = frozenset({"index.md", "log.md"})
FRONTMATTER_RE = re.compile(r"\A---\r?\n(.*?)\r?\n---\r?\n?", re.DOTALL)

# OKF v1 frontmatter 必填 10 字段（SSOT：agent/knowledge/okf-spec.md §2）
REQUIRED_FRONTMATTER_FIELDS = (
    "type",
    "title",
    "description",
    "tags",
    "timestamp",
    "full_id",
    "perspective",
    "hierarchy",
    "parent_id",
    "layer_scope",
)

# OKF v1 正文 4 段的中文落地标题；旧英文标题仅作为迁移兼容输入
REQUIRED_SECTIONS = ("关系", "跨视角", "详细说明", "依据与证据")
LEGACY_SECTION_ALIASES = {
    "Relations": "关系",
    "Cross-perspective": "跨视角",
    "Details": "详细说明",
    "Evidence": "依据与证据",
}
ALL_SECTION_TITLES = frozenset(REQUIRED_SECTIONS) | frozenset(LEGACY_SECTION_ALIASES.keys())

# OKF v1 合法 perspective 枚举
VALID_PERSPECTIVES = frozenset({"business", "product", "application", "data", "technical"})

# OKF v1 合法 layer_scope 枚举（与全仓现状一致：application / system / company）
VALID_LAYER_SCOPES = frozenset({"application", "system", "company"})

# ISO8601 时间戳正则（OKF v1 强制 UTC + Z 后缀）
ISO8601_RE = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")


def find_repo_root(start: Path) -> Path:
    """向上查找仓库根（含 .docsconfig 或 .git）。"""
    p = start.resolve()
    for parent in (p, *p.parents):
        if (parent / ".docsconfig").exists() or (parent / ".git").exists():
            return parent
    raise RuntimeError(f"无法定位仓库根（未找到 .docsconfig/.git），start={p}")


def normalize_section_heading(title: str) -> Optional[str]:
    title = title.strip()
    if title in REQUIRED_SECTIONS:
        return title
    return LEGACY_SECTION_ALIASES.get(title)

HIERARCHY_TO_TYPE: Dict[str, str] = {
    "BD": "Business Domain",
    "BSD": "Business Subdomain",
    "BC": "Bounded Context",
    "AGG": "Aggregate",
    "AB": "Ability",
    "PL": "Product Line",
    "PM": "Product Module",
    "FT": "Feature",
    "FR": "Functional Requirement",
    "UC": "Use Case",
    "SYS": "System",
    "APP": "Application",
    "MS": "Microservice",
    "API": "API Endpoint",
    "DS": "Data Store",
    "ENT": "Entity",
    "MDG": "Master Data Domain",
    "MW": "Middleware Binding",
    "CMP": "Component",
    "TSD": "Technical Subdomain",
    "CAP": "Business Capability",
    "TPL": "Technical Platform",
    "BP": "Business Process",
    "BR": "Business Rule",
    "TBL": "Data Table",
}

APPLICATION_PERSPECTIVE_DOMAIN_ANCHOR: Dict[str, str] = {
    "business": "BSD-EXAMPLE",
    "product": "PM-EXAMPLE",
    "application": "MS-EXAMPLE",
    "data": "ENT-EXAMPLE",
    "technical": "MW-EXAMPLE",
}

SYSTEM_PERSPECTIVE_DOMAIN_ANCHOR: Dict[str, str] = {
    "business": "BSD-EXAMPLE",
    "product": "PM-EXAMPLE",
    "application": "MS-EXAMPLE",
    "data": "DS-EXAMPLE",
    "technical": "MW-EXAMPLE",
}

COMPANY_PERSPECTIVE_DOMAIN_ANCHOR: Dict[str, str] = {
    "business": "BD-EXAMPLE",
    "product": "PL-EXAMPLE",
    "application": "SYS-EXAMPLE",
    "data": "MDG-EXAMPLE",
    "technical": "TPL-EXAMPLE",
}

# 默认 application bundle 锚点（向后兼容）
PERSPECTIVE_DOMAIN_ANCHOR = APPLICATION_PERSPECTIVE_DOMAIN_ANCHOR

# legacy：嵌套锚点规则（迁移前）；新落盘见 entity_relpath + PERSPECTIVE_DOMAIN_ANCHOR
PERSPECTIVE_ANCHOR_RULES: Dict[str, str] = {
    "business": "BD",
    "product": "PL",
    "application": "SYS",
    "data": "DS",
}

# application 层 reference concept（非本层 SSOT）
REFERENCE_FULL_IDS = frozenset(
    {
        "BD-EXAMPLE",
        "PL-EXAMPLE",
        "SYS-EXAMPLE",
        "APP-EXAMPLE",
        "MS-EXAMPLE",
        "DS-EXAMPLE",
        "ENT-EXAMPLE",
    }
)

_DEFAULT_PRODUCT_PL = "PL-EXAMPLE"
_DEFAULT_PRODUCT_PM = "PM-EXAMPLE"
_DEFAULT_DATA_DS = "DS-EXAMPLE"


def _id_prefix(full_id: str) -> str:
    return full_id.split("-", 1)[0]


def _parse_scalar(val: str) -> Any:
    val = val.strip()
    if val in ("null", "~", ""):
        return None
    if val.startswith("[") and val.endswith("]"):
        inner = val[1:-1].strip()
        if not inner:
            return []
        return [_strip_quotes(x.strip()) for x in inner.split(",") if x.strip()]
    return _strip_quotes(val)


def _strip_quotes(val: str) -> str:
    if len(val) >= 2 and val[0] == val[-1] and val[0] in ('"', "'"):
        return val[1:-1]
    return val


def parse_frontmatter(text: str) -> Tuple[Dict[str, Any], str]:
    """解析 YAML frontmatter（字符串、行内列表、null）。"""
    m = FRONTMATTER_RE.match(text)
    if not m:
        return {}, text
    block = m.group(1)
    body = text[m.end():]
    meta: Dict[str, Any] = {}
    for line in block.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if ":" not in line:
            continue
        key, val = line.split(":", 1)
        key = key.strip()
        meta[key] = _parse_scalar(val)
    return meta, body


def format_frontmatter(meta: Dict[str, Any]) -> str:
    """将 meta 序列化为 YAML frontmatter 块（含首尾 ---）。"""
    lines = ["---"]
    for key, val in meta.items():
        lines.append(f"{key}: {_format_yaml_value(val)}")
    lines.append("---")
    return "\n".join(lines) + "\n"


def _format_yaml_value(val: Any) -> str:
    if val is None:
        return "null"
    if isinstance(val, bool):
        return "true" if val else "false"
    if isinstance(val, list):
        if not val:
            return "[]"
        items = ", ".join(_format_yaml_scalar(x) for x in val)
        return f"[{items}]"
    return _format_yaml_scalar(val)


def _format_yaml_scalar(val: Any) -> str:
    if val is None:
        return "null"
    s = str(val)
    if s == "" or any(c in s for c in ":[]{}#&*!|>'\"%@`"):
        return f'"{s}"'
    return s


def hierarchy_to_type(hierarchy: str) -> str:
    return HIERARCHY_TO_TYPE.get(hierarchy, hierarchy)


HIERARCHY_TO_PERSPECTIVE: Dict[str, str] = {
    "BD": "business",
    "BSD": "business",
    "BC": "business",
    "AGG": "business",
    "AB": "business",
    "CAP": "business",
    "PL": "product",
    "PM": "product",
    "FT": "product",
    "FR": "product",
    "UC": "product",
    "BP": "product",
    "BR": "product",
    "SYS": "application",
    "APP": "application",
    "MS": "application",
    "API": "application",
    "MDG": "data",
    "DS": "data",
    "ENT": "data",
    "TBL": "data",
    "TPL": "technical",
    "TSD": "technical",
    "MW": "technical",
    "CMP": "technical",
}

# 首次定义层（SSOT：application/DESIGN.md §2.2.1）
HIERARCHY_FIRST_LAYER: Dict[str, str] = {
    "BD": "company",
    "CAP": "company",
    "PL": "company",
    "SYS": "company",
    "MDG": "company",
    "TPL": "company",
    "BSD": "system",
    "BC": "system",
    "AGG": "system",
    "AB": "system",
    "PM": "system",
    "BP": "system",
    "FT": "system",
    "FR": "system",
    "UC": "system",
    "BR": "system",
    "APP": "system",
    "MS": "system",
    "DS": "system",
    "ENT": "system",
    "TSD": "system",
    "API": "application",
    "TBL": "application",
    "MW": "application",
    "CMP": "application",
}


def hierarchy_first_layer(hierarchy: str) -> Optional[str]:
    return HIERARCHY_FIRST_LAYER.get(hierarchy)


def hierarchy_to_perspective(hierarchy: str) -> Optional[str]:
    return HIERARCHY_TO_PERSPECTIVE.get(hierarchy)


def perspective_domain_anchor(
    perspective: str,
    full_id: Optional[str] = None,
    bundle: str = "application",
) -> str:
    """域扁平树：返回 perspective 下域文件夹名。"""
    anchor_map = (
        COMPANY_PERSPECTIVE_DOMAIN_ANCHOR
        if bundle == "company"
        else SYSTEM_PERSPECTIVE_DOMAIN_ANCHOR
        if bundle == "system"
        else APPLICATION_PERSPECTIVE_DOMAIN_ANCHOR
    )
    return anchor_map.get(perspective, full_id or "")


def entity_relpath(
    perspective: str,
    full_id: str,
    parent_id: Optional[str] = None,
    bundle: str = "application",
) -> str:
    """相对 bundle 根的 concept 路径（域扁平树）。"""
    prefix = _id_prefix(full_id)
    if bundle == "company":
        if perspective == "business" and prefix == "BD":
            return f"knowledge/business/{full_id}/{full_id}.md"
        if perspective == "business" and prefix == "CAP":
            bd = parent_id or "BD-EXAMPLE"
            return f"knowledge/business/{bd}/{full_id}.md"
        if perspective == "product" and prefix == "PL":
            return f"knowledge/product/{full_id}.md"
        if perspective == "application" and prefix == "SYS":
            return f"knowledge/application/{full_id}.md"
        if perspective == "data" and prefix == "MDG":
            return f"knowledge/data/{full_id}.md"
        if perspective == "technical" and prefix == "TPL":
            return f"knowledge/technical/{full_id}.md"
        anchor = perspective_domain_anchor(perspective, full_id, bundle)
        if not anchor:
            return f"knowledge/{perspective}/{full_id}.md"
        return f"knowledge/{perspective}/{anchor}/{full_id}.md"

    if bundle == "system":
        if perspective == "business" and prefix == "BD":
            return f"knowledge/business/{full_id}.md"
        if perspective == "product" and prefix == "PL":
            return f"knowledge/product/{full_id}.md"
        if perspective == "application" and prefix == "SYS":
            return f"knowledge/application/{full_id}.md"
        if perspective == "application" and prefix == "APP":
            return f"knowledge/application/{full_id}/{full_id}.md"
        if perspective == "application" and prefix == "MS":
            if not parent_id:
                raise ValueError(
                    "entity_relpath: system MS requires parent_id (APP full_id)"
                )
            return f"knowledge/application/{parent_id}/{full_id}/{full_id}.md"
        if perspective == "data" and prefix == "MDG":
            return f"knowledge/data/{full_id}.md"
        if perspective == "technical" and prefix == "TSD":
            return f"knowledge/technical/{full_id}.md"
        if perspective == "technical" and prefix == "MW":
            return f"knowledge/technical/{full_id}/{full_id}.md"
        anchor = perspective_domain_anchor(perspective, full_id, bundle)
        if not anchor:
            return f"knowledge/{perspective}/{full_id}.md"
        return f"knowledge/{perspective}/{anchor}/{full_id}.md"

    if perspective == "application" and prefix in ("SYS", "APP"):
        return f"knowledge/application/{full_id}.md"
    if perspective == "business" and prefix == "BD":
        return f"knowledge/business/{full_id}.md"
    if perspective == "data" and prefix == "DS":
        return f"knowledge/data/{full_id}.md"
    if perspective == "product" and prefix == "PL":
        return f"knowledge/product/{full_id}.md"
    anchor = perspective_domain_anchor(perspective, full_id, bundle)
    if not anchor:
        return f"knowledge/{perspective}/{full_id}.md"
    return f"knowledge/{perspective}/{anchor}/{full_id}.md"


def to_bundle_link(relpath: str) -> str:
    if not relpath.startswith("/"):
        return "/" + relpath.lstrip("/")
    return relpath


def is_concept_file(path: Path) -> bool:
    return path.suffix == ".md" and path.name not in OKF_RESERVED_NAMES


def scan_concepts(bundle_root: Path) -> Iterator[Path]:
    """遍历 bundle 下所有 concept 文件路径（相对 bundle_root 的绝对 Path）。"""
    root = bundle_root.resolve()
    if not root.is_dir():
        return
    for path in sorted(root.rglob("*.md")):
        if is_concept_file(path):
            yield path
