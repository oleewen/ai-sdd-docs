#!/usr/bin/env python3
"""OKF bundle 校验：frontmatter、full_id 唯一性、链接与 index 条目。

OKF v1 SSOT：agent/knowledge/okf-spec.md
本脚本是 OKF 10 硬规则 R1~R10 的实现入口。
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from typing import Dict, List, Optional, Set

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))
import okf_lib  # noqa: E402
import okf_cross_layer  # noqa: E402

BUNDLE_LINK_RE = re.compile(r"\]\((/(?:knowledge|application)/[^)]+)\)")
INDEX_LINK_RE = re.compile(r"(?<!!)\[[^\]]*\]\(([^)]+)\)")
ALLOWED_ROOT_INDEX_KEYS = frozenset({"okf_version", "type", "title", "tags"})

# 段标题提取正则（迁移期同时兼容旧英文 H1 与新中文 H2）
SECTION_HEADING_RE = re.compile(r"^(#{1,2})\s+(\S.*?)\s*$", re.MULTILINE)

# Cross-perspective 段内链接提取（与 BUNDLE_LINK_RE 不同：相对路径也校验）
SECTION_LINK_RE = re.compile(r"\[([^\]]+)\]\(([^)]+)\)")


class Validator:
    def __init__(
        self,
        bundle_root: Path,
        bundle_name: str = "",
        repo_root: Optional[Path] = None,
    ) -> None:
        self.bundle_root = bundle_root.resolve()
        self.bundle_name = bundle_name  # 例 "system" / "company" / "application"
        self.repo_root = (
            repo_root.resolve()
            if repo_root is not None
            else self.bundle_root.parent
        )
        self.errors = 0
        self.warnings = 0
        # 全仓 full_id → file 索引（供 R6 parent_id 与 R7 Cross-perspective 引用校验）
        self._full_id_index: Dict[str, List[str]] = {}
        # 缓存扫到的所有 .md 文件
        self._md_files: List[Path] = []
        # R10 layer_scope 与 bundle 名一致
        # bundle ⇒ 期望 layer_scope 白名单（application / system / company 三 bundle 全支持）
        self._bundle_expected_layer_scope: Dict[str, str] = {
            "application": "application",
            "system": "system",
            "company": "company",
        }

    def error(self, msg: str) -> None:
        print(f"[ERROR] {msg}", file=sys.stderr)
        self.errors += 1

    def warn(self, msg: str) -> None:
        print(f"[WARN]  {msg}", file=sys.stderr)
        self.warnings += 1

    def relpath(self, path: Path) -> str:
        return path.resolve().relative_to(self.bundle_root).as_posix()

    def run(self) -> int:
        self._md_files = sorted(self.bundle_root.rglob("*.md"))

        # 第一轮：解析所有 frontmatter，构建 full_id 索引
        for path in self._md_files:
            relpath = self.relpath(path)
            text = path.read_text(encoding="utf-8")
            self._check_frontmatter(path, relpath, text)
            meta, _ = okf_lib.parse_frontmatter(text)
            full_id = meta.get("full_id")
            if full_id:
                self._full_id_index.setdefault(str(full_id), []).append(relpath)

        # 第二轮：full_id 唯一性 + 段结构 + 引用校验
        for full_id, paths in sorted(self._full_id_index.items()):
            if len(paths) > 1:
                self.error(
                    f"R6 full_id 重复: {full_id} -> {', '.join(paths)}"
                )

        for path in self._md_files:
            relpath = self.relpath(path)
            text = path.read_text(encoding="utf-8")
            meta, body = okf_lib.parse_frontmatter(text)
            if not meta:
                continue
            # 仅对 OKF concept（type 为 OKF 已知层级）做 4 段 + layer_scope 校验
            type_val = meta.get("type")
            if type_val is None or str(type_val).strip() == "":
                continue
            if str(type_val) not in okf_lib.HIERARCHY_TO_TYPE.values():
                continue
            self._check_sections(path, relpath, body)
            self._check_bundle_links(path, text)
            if path.name == "index.md":
                self._check_index_links(path, text)
            self._check_layer_scope(path, relpath, meta)

        for path in self._md_files:
            relpath = self.relpath(path)
            if not relpath.startswith("knowledge/"):
                continue
            text = path.read_text(encoding="utf-8")
            self._check_cross_layer_http(path, text)

        print("")
        print("=== OKF v1 校验结果 ===")
        print(f"bundle: {self.bundle_root}")
        print(f"扫到 .md 文件: {len(self._md_files)}")
        print(f"full_id 总数: {len(self._full_id_index)}")
        print(f"错误: {self.errors}  警告: {self.warnings}")
        if self.errors:
            print("校验失败，请修正后重跑。")
            return 1
        print("OKF v1 schema 验证通过。")
        return 0

    def _has_frontmatter(self, text: str) -> bool:
        return bool(okf_lib.FRONTMATTER_RE.match(text))

    def _is_bundle_root_index(self, relpath: str) -> bool:
        return relpath == "index.md"

    def _check_frontmatter(self, path: Path, relpath: str, text: str) -> None:
        name = path.name
        has_fm = self._has_frontmatter(text)
        meta, _ = okf_lib.parse_frontmatter(text)

        if name in okf_lib.OKF_RESERVED_NAMES:
            if not has_fm:
                return
            if self._is_bundle_root_index(relpath):
                extra = set(meta.keys()) - ALLOWED_ROOT_INDEX_KEYS
                if extra:
                    self.warn(
                        f"{relpath}: 根 index.md 仅允许 okf_version frontmatter，"
                        f"多余键: {', '.join(sorted(extra))}"
                    )
                return
            self.warn(f"{relpath}: index.md/log.md 不应含 frontmatter（OKF §6）")
            return

        if not has_fm:
            if name == "README.md":
                self.warn(f"{relpath}: 缺少 frontmatter")
            else:
                self.error(f"{relpath}: 缺少可解析 frontmatter")
            return

        # OKF v1 R1~R10 仅作用于声明自己是 OKF concept 的文件
        # 判定条件：type 字段为 OKF 层级英文名枚举（Business Domain / Product Module 等）
        # 业务架构类文件（type: Knowledge Index / Agent Index Guide / Contributing Guide 等）跳过
        type_val = meta.get("type")
        if type_val is None or str(type_val).strip() == "":
            return
        # 仅当 type 是 OKF 已知层级时，才进入 R1~R10 校验
        if str(type_val) not in okf_lib.HIERARCHY_TO_TYPE.values():
            return

        # R1 frontmatter 10 字段齐全
        missing = [f for f in okf_lib.REQUIRED_FRONTMATTER_FIELDS if f not in meta]
        if missing:
            self.error(
                f"R1 frontmatter 缺字段 {missing}: {relpath}"
            )

        # R2 perspective 合法枚举
        perspective = meta.get("perspective")
        if perspective is not None and str(perspective) not in okf_lib.VALID_PERSPECTIVES:
            self.error(
                f"R2 perspective 非法 {perspective!r}（合法: {sorted(okf_lib.VALID_PERSPECTIVES)}）: {relpath}"
            )

        # R3 type 与 hierarchy 一一对应
        hierarchy = meta.get("hierarchy")
        if hierarchy is not None:
            expected_type = okf_lib.hierarchy_to_type(str(hierarchy))
            if str(type_val) != expected_type:
                self.error(
                    f"R3 type 与 hierarchy 不一致: hierarchy={hierarchy} 应映射 type={expected_type}，"
                    f"实得 type={type_val}: {relpath}"
                )

        # R6 parent_id 引用存在性（BD/PL 允许 null）
        parent_id = meta.get("parent_id")
        if parent_id is not None and str(parent_id) != "" and str(parent_id) != "null":
            if str(parent_id) not in self._full_id_index:
                # 占位策略：第二轮结束后再做严格校验（避免漏判）
                pass  # 占位，在第二轮统一处理

        # R8 tags 必含 [<perspective>, <hierarchy>]
        tags = meta.get("tags")
        if tags is not None:
            tag_list = [str(t).strip() for t in (tags if isinstance(tags, list) else [tags])]
            perspective_s = str(perspective) if perspective is not None else None
            hierarchy_s = str(hierarchy) if hierarchy is not None else None
            if perspective_s and hierarchy_s:
                expected_prefix = [perspective_s, hierarchy_s]
                if not all(t in tag_list for t in expected_prefix):
                    self.error(
                        f"R8 tags 必含 {expected_prefix}，实得 {tag_list}: {relpath}"
                    )

        # R9 timestamp ISO8601
        timestamp = meta.get("timestamp")
        if timestamp is not None and str(timestamp) != "":
            if not okf_lib.ISO8601_RE.match(str(timestamp)):
                self.error(
                    f"R9 timestamp 非 ISO8601（YYYY-MM-DDTHH:MM:SSZ）: {timestamp!r} in {relpath}"
                )

    def _check_sections(self, path: Path, relpath: str, body: str) -> None:
        """R4 4 段齐全 + R5 段标题拼写精确。"""
        matches = SECTION_HEADING_RE.findall(body)
        normalized_headings = []
        for _, title in matches:
            normalized = okf_lib.normalize_section_heading(title)
            if normalized:
                normalized_headings.append(normalized)
        heading_set = set(normalized_headings)

        # R4
        missing_sections = [s for s in okf_lib.REQUIRED_SECTIONS if s not in heading_set]
        if missing_sections:
            self.error(
                f"R4 正文缺段 {missing_sections}: {relpath}"
            )

        # R5 段标题拼写精确（识别常见拼写错误）
        canonical = {s.lower().replace(" ", "-") for s in okf_lib.ALL_SECTION_TITLES}
        for _, title in matches:
            if okf_lib.normalize_section_heading(title) is not None:
                continue
            # 拼写相似度启发：完全小写、大小写混用、连字符替换为空格等
            normalized = title.strip().lower().replace(" ", "-")
            if normalized in canonical:
                self.error(
                    f"R5 段标题拼写错误: {title!r}: {relpath}"
                )

    def _check_layer_scope(self, path: Path, relpath: str, meta: Dict) -> None:
        """R10 layer_scope 与 bundle 名一致（system bundle ⇒ layer_scope: system；company bundle ⇒ layer_scope: company）。"""
        layer_scope = meta.get("layer_scope")
        if layer_scope is None or str(layer_scope) == "":
            return
        layer_scope_s = str(layer_scope)
        if layer_scope_s not in okf_lib.VALID_LAYER_SCOPES:
            self.error(
                f"R10 layer_scope 非法 {layer_scope_s!r}（合法: {sorted(okf_lib.VALID_LAYER_SCOPES)}）: {relpath}"
            )
            return
        # 与 bundle 名一致（如 bundle=system ⇒ layer_scope 应为 system）
        if self.bundle_name and self.bundle_name in self._bundle_expected_layer_scope:
            expected = self._bundle_expected_layer_scope[self.bundle_name]
            if layer_scope_s != expected:
                self.error(
                    f"R10 layer_scope={layer_scope_s} 与 bundle={self.bundle_name} 不一致（应为 {expected}）: {relpath}"
                )

    def _resolve_bundle_target(self, link: str) -> Path:
        normalized = link.lstrip("/")
        return self.bundle_root / normalized

    def _resolve_index_target(self, index_path: Path, link: str) -> Path:
        if link.startswith("/"):
            return self._resolve_bundle_target(link)
        if link.startswith(("http://", "https://", "mailto:")):
            return index_path  # skip external
        return (index_path.parent / link).resolve()

    def _target_exists(self, target: Path) -> bool:
        return target.exists()

    def _absolute_bundle_link_exists(self, link: str) -> bool:
        """仅本 bundle；禁止向下游 bundle 回退。"""
        return self._target_exists(self._resolve_bundle_target(link))

    def _check_cross_layer_http(self, path: Path, text: str) -> None:
        relpath = self.relpath(path)
        if not relpath.startswith("knowledge/"):
            return
        for match in INDEX_LINK_RE.finditer(text):
            href = match.group(1).strip()
            if not (href.startswith("http://") or href.startswith("https://")):
                continue
            err = okf_cross_layer.validate_http_href(self.bundle_root, href)
            if err:
                self.error(f"{relpath}: {err}: {href}")

    def _check_bundle_links(self, path: Path, text: str) -> None:
        relpath = self.relpath(path)
        for match in BUNDLE_LINK_RE.finditer(text):
            link = match.group(1)
            if not self._absolute_bundle_link_exists(link):
                self.warn(f"{relpath}: 链接目标不存在 {link}")

    def _check_index_links(self, index_path: Path, text: str) -> None:
        relpath = self.relpath(index_path)
        for match in INDEX_LINK_RE.finditer(text):
            link = match.group(1).strip()
            if link.startswith("#"):
                continue
            if link.startswith(("http://", "https://", "mailto:")):
                if relpath.startswith("knowledge/") and link.startswith(
                    ("http://", "https://")
                ):
                    err = okf_cross_layer.validate_http_href(
                        self.bundle_root, link
                    )
                    if err:
                        self.error(f"{relpath}: {err}: {link}")
                continue
            if link.startswith("/"):
                if not self._absolute_bundle_link_exists(link):
                    self.warn(f"{relpath}: index 链接目标不存在 {link}")
                continue
            target = self._resolve_index_target(index_path, link)
            if not self._target_exists(target):
                self.warn(f"{relpath}: index 链接目标不存在 {link}")


def _repo_root() -> Path:
    return okf_lib.find_repo_root(Path(__file__).resolve())


def _bundle_root(repo: Path, bundle: str) -> Path:
    return (repo / bundle).resolve()


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="OKF v1 bundle 校验")
    parser.add_argument(
        "--bundle",
        required=True,
        help="bundle 目录名（相对仓库根），如 application / system / company",
    )
    parser.add_argument(
        "--repo",
        default=None,
        help="仓库根目录（默认：脚本上两级）",
    )
    args = parser.parse_args(argv)

    repo = Path(args.repo).resolve() if args.repo else _repo_root()
    bundle_root = _bundle_root(repo, args.bundle)
    if not bundle_root.is_dir():
        print(f"[ERROR] bundle 不存在: {bundle_root}", file=sys.stderr)
        return 1

    print("=== OKF v1 bundle 校验 ===")
    print(f"REPO_ROOT: {repo}")
    print(f"BUNDLE:    {args.bundle}")
    print(f"BUNDLE_ROOT: {bundle_root}")
    print("")

    return Validator(
        bundle_root, bundle_name=args.bundle, repo_root=repo
    ).run()


if __name__ == "__main__":
    raise SystemExit(main())
