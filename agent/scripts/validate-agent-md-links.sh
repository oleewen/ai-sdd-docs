#!/usr/bin/env bash
# validate-agent-md-links.sh — 校验 agent 下 Markdown 链接：agent 内互链须存在；跨出 agent 须落在
# REPO_ROOT 或 DOC_ROOT 下（且非 .git），落实 link-reachability §1.1 强校验。
# 在仓库根执行：bash agent/scripts/validate-agent-md-links.sh
# 文档根路径来自目标仓库根 .docsconfig（见 config-bootstrap.sh；§2.2.2 不向子进程 export，仅前缀传参）。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/config-bootstrap.sh"
validate_bootstrap_docsconfig "$SCRIPT_DIR"

AGENT_DIR="$REPO_ROOT/agent"
[[ -d "$AGENT_DIR" ]] || {
  echo "[ERROR] 未找到 ${AGENT_DIR}（REPO_ROOT=$REPO_ROOT）"
  exit 1
}

# §2.2.2：不 export；仅对本次 python3 进程传入环境变量
DOC_ROOT="$DOC_ROOT" REPO_ROOT="$REPO_ROOT" DOC_DIR="${DOC_DIR:-}" AGENT_DIR="$AGENT_DIR" \
  python3 <<'PY'
import os
import re
import sys

repo = os.environ["REPO_ROOT"]
agent = os.environ["AGENT_DIR"]
doc_root = os.environ["DOC_ROOT"]
link_re = re.compile(r"\]\(([^)]+)\)")

errs = []
warns = []
exists_cache: dict[str, bool] = {}


def norm(p: str) -> str:
    return os.path.normpath(p)


def path_exists(path: str) -> bool:
    key = norm(path)
    if key not in exists_cache:
        exists_cache[key] = os.path.exists(path)
    return exists_cache[key]


def is_under(path: str, root: str) -> bool:
    a, b = norm(path), norm(root)
    return a == b or a.startswith(b + os.sep)


def is_external(p: str) -> bool:
    p = p.strip()
    return not p or p.startswith(("#", "http://", "https://", "mailto:"))


git_dir = os.path.join(repo, ".git")

for dirpath, _, files in os.walk(agent):
    for name in files:
        if not name.endswith(".md"):
            continue
        path = os.path.join(dirpath, name)
        rel_md = os.path.relpath(path, repo)
        try:
            with open(path, encoding="utf-8") as f:
                text = f.read()
        except (OSError, UnicodeDecodeError) as e:
            warns.append(f"{rel_md}: 无法读取 ({e})")
            continue
        for m in link_re.finditer(text):
            target = m.group(1).strip().split("#", 1)[0].strip()
            if is_external(target):
                continue
            joined = norm(os.path.join(os.path.dirname(path), target))
            # agent 内互链：目标须在 agent 下且存在（含 L3 裸链规则）
            if is_under(joined, agent):
                if not path_exists(joined):
                    errs.append(f"{rel_md}: 目标不存在 → ({target})")
            else:
                # 跨出 agent：须落在 REPO_ROOT 或 DOC_ROOT 目录树内
                if not (is_under(joined, repo) or is_under(joined, doc_root)):
                    errs.append(
                        f"{rel_md}: 跨出 agent 的链接须指向 REPO_ROOT 或 DOC_ROOT 下路径 → ({target})"
                    )
                    continue
                if is_under(joined, git_dir):
                    errs.append(f"{rel_md}: 禁止链接到 .git → ({target})")
                    continue
                if not path_exists(joined):
                    errs.append(f"{rel_md}: 目标不存在 → ({target})")
            # 深层 reference 禁止裸 application|docs 根链（规范 L3）
            target_slash = target.replace("\\", "/")
            if "/reference/" in rel_md.replace("\\", "/") and re.match(
                r"^(application|docs)/", target_slash
            ):
                errs.append(
                    f"{rel_md}: 深层 reference 禁止使用裸 ({target})，须 ../../../ 等到仓库根"
                )

if warns:
    for w in warns:
        print("[WARN]", w, file=sys.stderr)
if errs:
    print(f"校验失败（{len(errs)}）:", file=sys.stderr)
    for e in errs:
        print(" ", e, file=sys.stderr)
    sys.exit(1)
print(f"[OK] agent Markdown 链接检查通过（agent 内互链 + 跨边界须 REPO_ROOT/DOC_ROOT；DOC_ROOT={doc_root}）")
PY
