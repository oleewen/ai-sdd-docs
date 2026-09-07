#!/usr/bin/env python3
"""跨层 HTTP / knowledge-parent.yaml（SSOT：knowledge-governance 引用边界）。"""

from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterator, List, Optional, Tuple
from urllib.parse import urlparse

import okf_lib

PARENT_FILENAME = "knowledge-parent.yaml"
MD_LINK_RE = re.compile(r"\[([^\]]+)\]\((https?://[^)\s]+)\)")
KNOWN_BLOB: Dict[str, str] = {
    "github.com": "/blob/{ref}/",
    "www.github.com": "/blob/{ref}/",
    "gitlab.com": "/-/blob/{ref}/",
    "www.gitlab.com": "/-/blob/{ref}/",
    "gitee.com": "/blob/{ref}/",
    "www.gitee.com": "/blob/{ref}/",
}


@dataclass(frozen=True)
class Parent:
    knowledge_type: str
    repository: str
    path: str
    doc_dir: str
    ref: str = "main"

    def expanded_path(self) -> Path:
        return Path(self.path).expanduser()

    def local_doc_root(self) -> Path:
        base = self.expanded_path()
        dd = (self.doc_dir or "").strip()
        if dd in ("", "."):
            return base
        return base / dd


def _yaml_scalar(val: str) -> str:
    val = val.strip()
    if len(val) >= 2 and val[0] == val[-1] and val[0] in ('"', "'"):
        return val[1:-1]
    return val


def parent_yaml_path(doc_root: Path) -> Path:
    return Path(doc_root) / PARENT_FILENAME


def load_parent(doc_root: Path) -> Optional[Parent]:
    path = parent_yaml_path(doc_root)
    if not path.is_file():
        return None
    text = path.read_text(encoding="utf-8")
    fields: Dict[str, str] = {}
    in_parent = False
    for raw in text.splitlines():
        line = raw.rstrip()
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if line.strip() == "parent:" or line.startswith("parent:"):
            in_parent = True
            continue
        if not in_parent:
            continue
        if line and not line.startswith((" ", "\t")) and ":" in line:
            break
        stripped = line.strip()
        if ":" not in stripped:
            continue
        key, _, rest = stripped.partition(":")
        fields[key.strip()] = _yaml_scalar(rest)
    kt = fields.get("knowledge_type", "").strip()
    repo = fields.get("repository", "").strip()
    stored_path = fields.get("path", "").strip()
    doc_dir = fields.get("doc_dir", "").strip()
    ref = fields.get("ref", "").strip() or "main"
    if not kt or not stored_path or not doc_dir:
        return None
    return Parent(
        knowledge_type=kt,
        repository=repo,
        path=stored_path,
        doc_dir=doc_dir,
        ref=ref,
    )


def dump_parent(parent: Parent) -> str:
    def q(s: str) -> str:
        return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'

    lines = [
        "# 上级知识库 identity（docs-link 维护；1:1）",
        "parent:",
        f"  knowledge_type: {parent.knowledge_type}",
        f"  repository: {q(parent.repository)}",
        f"  path: {q(parent.path)}",
        f"  doc_dir: {q(parent.doc_dir)}",
        f"  ref: {q(parent.ref)}",
        "",
    ]
    return "\n".join(lines)


def write_parent(doc_root: Path, parent: Parent, *, dry_run: bool = False) -> Path:
    dest = parent_yaml_path(doc_root)
    text = dump_parent(parent)
    if dry_run:
        return dest
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(text, encoding="utf-8")
    return dest


def delete_parent(doc_root: Path, *, dry_run: bool = False) -> None:
    dest = parent_yaml_path(doc_root)
    if dry_run or not dest.is_file():
        return
    dest.unlink()


def https_repo_home(repository: str) -> Optional[str]:
    raw = (repository or "").strip()
    if not raw:
        return None
    if raw.startswith("git@"):
        # git@host:owner/repo.git
        rest = raw[4:]
        if ":" not in rest:
            return None
        host, path = rest.split(":", 1)
        path = path.removesuffix(".git")
        return f"https://{host}/{path}"
    if raw.startswith("ssh://"):
        parsed = urlparse(raw)
        host = parsed.hostname or ""
        path = (parsed.path or "").lstrip("/").removesuffix(".git")
        if not host or not path:
            return None
        return f"https://{host}/{path}"
    if raw.startswith("http://") or raw.startswith("https://"):
        parsed = urlparse(raw)
        host = parsed.netloc
        path = (parsed.path or "").removesuffix(".git").rstrip("/")
        if not host:
            return None
        scheme = "https" if parsed.scheme == "http" else parsed.scheme
        return f"{scheme}://{host}{path}"
    return None


def blob_infix(host: str, ref: str) -> Optional[str]:
    host = host.lower()
    tmpl = KNOWN_BLOB.get(host)
    if not tmpl:
        return None
    return tmpl.format(ref=ref)


def parent_web_base(parent: Parent) -> Optional[str]:
    home = https_repo_home(parent.repository)
    if not home:
        return None
    host = urlparse(home).hostname or ""
    infix = blob_infix(host, parent.ref)
    if not infix:
        return None
    dd = (parent.doc_dir or "").strip()
    if dd in ("", "."):
        return f"{home}{infix}".rstrip("/")
    return f"{home}{infix}{dd}".rstrip("/")


def walk_parents(start_doc_root: Path) -> Iterator[Parent]:
    seen: set[str] = set()
    current = load_parent(start_doc_root)
    while current is not None:
        key = f"{current.knowledge_type}|{current.path}|{current.doc_dir}"
        if key in seen:
            return
        seen.add(key)
        yield current
        nxt = current.local_doc_root()
        if not nxt.is_dir():
            return
        current = load_parent(nxt)


def parent_for_layer(start_doc_root: Path, knowledge_type: str) -> Optional[Parent]:
    for p in walk_parents(start_doc_root):
        if p.knowledge_type == knowledge_type:
            return p
    return None


def collect_web_bases(start_doc_root: Path) -> List[Tuple[Parent, str]]:
    out: List[Tuple[Parent, str]] = []
    for p in walk_parents(start_doc_root):
        wb = parent_web_base(p)
        if wb:
            out.append((p, wb))
    return out


def cross_layer_href(
    start_doc_root: Path,
    full_id: str,
    *,
    parent_id: Optional[str] = None,
    hierarchy: Optional[str] = None,
) -> Optional[str]:
    prefix = hierarchy or okf_lib._id_prefix(full_id)
    layer = okf_lib.hierarchy_first_layer(prefix)
    perspective = okf_lib.hierarchy_to_perspective(prefix)
    if not layer or not perspective:
        return None
    parent = parent_for_layer(start_doc_root, layer)
    if parent is None:
        return None
    wb = parent_web_base(parent)
    if not wb:
        return None
    rel = okf_lib.entity_relpath(
        perspective, full_id, parent_id=parent_id, bundle=layer
    )
    return f"{wb}/{rel}"


def iter_knowledge_md(doc_root: Path) -> Iterator[Path]:
    root = Path(doc_root) / "knowledge"
    if not root.is_dir():
        return
    yield from sorted(root.rglob("*.md"))


def rewrite_web_base(
    doc_root: Path,
    old_web_base: str,
    new_web_base: Optional[str],
    *,
    dry_run: bool = False,
) -> int:
    """替换或拆成纯 ID。返回改写文件数。"""
    if not old_web_base:
        return 0
    changed = 0
    for path in iter_knowledge_md(doc_root):
        text = path.read_text(encoding="utf-8")
        new_text, n = _rewrite_text(text, old_web_base, new_web_base)
        if n:
            changed += 1
            if not dry_run:
                path.write_text(new_text, encoding="utf-8")
    return changed


def _rewrite_text(
    text: str, old_web_base: str, new_web_base: Optional[str]
) -> Tuple[str, int]:
    count = 0

    def repl(m: re.Match[str]) -> str:
        nonlocal count
        label, url = m.group(1), m.group(2)
        if not (url == old_web_base or url.startswith(old_web_base + "/")):
            return m.group(0)
        count += 1
        if new_web_base:
            suffix = url[len(old_web_base) :]
            return f"[{label}]({new_web_base}{suffix})"
        return label

    return MD_LINK_RE.sub(repl, text), count


def unlink_http_to_id(doc_root: Path, *, dry_run: bool = False) -> int:
    parent = load_parent(doc_root)
    if parent is None:
        return 0
    wb = parent_web_base(parent)
    if not wb:
        return 0
    return rewrite_web_base(doc_root, wb, None, dry_run=dry_run)


def expected_relpath_for_url(
    parent: Parent, url: str, web_base: str
) -> Optional[str]:
    if not (url == web_base or url.startswith(web_base + "/")):
        return None
    rel = url[len(web_base) :].lstrip("/")
    return rel or None


def validate_http_href(
    start_doc_root: Path, href: str
) -> Optional[str]:
    """返回错误信息；合法则 None。无 parent 时任何 http(s) 均非法。"""
    if not (href.startswith("http://") or href.startswith("https://")):
        return None
    bases = collect_web_bases(start_doc_root)
    if load_parent(start_doc_root) is None:
        return "跨层 HTTP 但缺少 knowledge-parent.yaml"
    if not bases:
        return "有 knowledge-parent.yaml 但无法从 repository 推导已知托管的 HTTP 前缀"
    matched: Optional[Tuple[Parent, str]] = None
    for parent, wb in bases:
        if href == wb or href.startswith(wb + "/"):
            matched = (parent, wb)
            break
    if matched is None:
        allowed = ", ".join(wb for _, wb in bases)
        return f"跨层 HTTP 前缀不匹配（允许 web_base: {allowed}）"
    parent, wb = matched
    rel = expected_relpath_for_url(parent, href, wb)
    if not rel or not rel.startswith("knowledge/"):
        return f"跨层 HTTP 缺少目标层 knowledge 相对路径: {href}"
    name = Path(rel).name
    if not name.endswith(".md"):
        return f"跨层 HTTP 未指向 .md: {href}"
    full_id = name[:-3]
    prefix = okf_lib._id_prefix(full_id)
    perspective = okf_lib.hierarchy_to_perspective(prefix)
    if not perspective:
        return f"跨层 HTTP 无法识别实体 ID: {full_id}"
    try:
        expected = okf_lib.entity_relpath(
            perspective, full_id, bundle=parent.knowledge_type
        )
    except ValueError:
        expected = None
    if expected and rel != expected:
        # MS 等需要 parent_id 时 entity_relpath 可能抛错或路径不同；允许后缀匹配文件名
        if not rel.endswith(f"/{name}") and rel != expected:
            return (
                f"跨层 HTTP 路径与目标层 entity_relpath 不一致: "
                f"得 {rel} 期望 {expected}"
            )
    local_root = parent.local_doc_root()
    if local_root.is_dir():
        target = local_root / rel
        if not target.is_file():
            return f"本机上级文件不存在: {target}"
    return None
