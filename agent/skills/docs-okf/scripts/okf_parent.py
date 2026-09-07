#!/usr/bin/env python3
"""docs-link 配套：写入 knowledge-parent.yaml 并改写跨层 HTTP。"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from typing import Optional

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))
import okf_cross_layer as x  # noqa: E402


def _cmd_write(args: argparse.Namespace) -> int:
    doc_root = Path(args.doc_root)
    new = x.Parent(
        knowledge_type=args.knowledge_type,
        repository=args.repository or "",
        path=args.path,
        doc_dir=args.doc_dir,
        ref=args.ref or "main",
    )
    old = x.load_parent(doc_root)
    old_wb = x.parent_web_base(old) if old else None
    new_wb = x.parent_web_base(new)
    if old_wb and old_wb != new_wb:
        n = x.rewrite_web_base(doc_root, old_wb, new_wb, dry_run=args.dry_run)
        print(f"web_base 替换文件数: {n}", file=sys.stderr)
    x.write_parent(doc_root, new, dry_run=args.dry_run)
    if args.dry_run:
        print(f"[dry-run] 将写入 {x.parent_yaml_path(doc_root)}")
    else:
        print(f"已写入 {x.parent_yaml_path(doc_root)}")
    return 0


def _cmd_unlink(args: argparse.Namespace) -> int:
    doc_root = Path(args.doc_root)
    n = x.unlink_http_to_id(doc_root, dry_run=args.dry_run)
    print(f"跨层 HTTP 改为纯 ID 的文件数: {n}", file=sys.stderr)
    if not args.dry_run:
        x.delete_parent(doc_root)
        print(f"已删除 {x.parent_yaml_path(doc_root)}")
    else:
        print(f"[dry-run] 将删除 {x.parent_yaml_path(doc_root)}")
    return 0


def _cmd_href(args: argparse.Namespace) -> int:
    href = x.cross_layer_href(
        Path(args.doc_root),
        args.full_id,
        parent_id=args.parent_id,
        hierarchy=args.hierarchy,
    )
    if href:
        print(href)
        return 0
    print("", end="")
    return 1


def main(argv: Optional[list] = None) -> int:
    parser = argparse.ArgumentParser(description="knowledge-parent.yaml 与跨层 HTTP")
    parser.add_argument("--dry-run", action="store_true")
    sub = parser.add_subparsers(dest="cmd", required=True)

    w = sub.add_parser("write")
    w.add_argument("--doc-root", required=True)
    w.add_argument("--knowledge-type", required=True)
    w.add_argument("--repository", default="")
    w.add_argument("--path", required=True)
    w.add_argument("--doc-dir", required=True)
    w.add_argument("--ref", default="main")
    w.set_defaults(func=_cmd_write)

    u = sub.add_parser("unlink")
    u.add_argument("--doc-root", required=True)
    u.set_defaults(func=_cmd_unlink)

    h = sub.add_parser("href")
    h.add_argument("--doc-root", required=True)
    h.add_argument("--full-id", required=True)
    h.add_argument("--parent-id", default=None)
    h.add_argument("--hierarchy", default=None)
    h.set_defaults(func=_cmd_href)

    args = parser.parse_args(argv)
    return int(args.func(args))


if __name__ == "__main__":
    raise SystemExit(main())
