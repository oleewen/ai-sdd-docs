#!/usr/bin/env bash
set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../docs-install/test-lib.sh
source "$TEST_DIR/../../docs-install/test-lib.sh"

if [[ "${BASH_VERSINFO[0]:-0}" -lt 5 ]]; then
  pass "跳过（需 Bash 5+）"
  exit 0
fi

TMP_DIR="$(new_tmp_dir)"
ROOT_DIR="$(cd "$TEST_DIR/../../../.." && pwd)"
PULL="$ROOT_DIR/agent/skills/docs-pull/scripts/pull-slots.sh"

cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

COMPANY="$TMP_DIR/company"
SYS="$TMP_DIR/sys-foo"

mkdir -p "$COMPANY/docs" "$SYS/docs"
git -C "$COMPANY" init -q
git -C "$SYS" init -q
git -C "$SYS" remote add origin "https://example.com/org/sys-foo.git"

cat >"$COMPANY/.docsconfig" <<EOF
DOC_ROOT=docs
REPO_ROOT=$COMPANY
DOC_DIR=docs
KNOWLEDGE_TYPE=company
AGENT_ROOT=$ROOT_DIR/agent
AGENT_DIRS=.cursor
EOF

# 目标系统仓：正文在 DOC_ROOT（常见 DOC_DIR=docs），禁止再拼成 docs/docs
cat >"$SYS/.docsconfig" <<EOF
DOC_ROOT=docs
REPO_ROOT=$SYS
DOC_DIR=docs
KNOWLEDGE_TYPE=system
AGENT_ROOT=$ROOT_DIR/agent
AGENT_DIRS=.cursor
EOF

mkdir -p "$COMPANY/docs/system-sys-foo/changelogs"
echo "# CHANGE LOG - SYSNAME" >"$COMPANY/docs/system-sys-foo/changelogs/CHANGE-LOG.md"
echo "# slot wrapper" >"$COMPANY/docs/system-sys-foo/README.md"
echo "# slot index" >"$COMPANY/docs/system-sys-foo/index.md"

echo "content" >"$SYS/docs/sync-me.md"

cat >"$COMPANY/docs/knowledge-links.yaml" <<EOF
links:
  - repository: "https://example.com/org/sys-foo.git"
    path: "$SYS"
    doc_dir: "system"
    sys_name: "sys-foo"
    sys_label: "sys-foo"
EOF

git -C "$SYS" add .
git -C "$SYS" commit -m "init sys docs" -q

set +e
out="$(cd "$COMPANY" && "${BASH:-bash}" "$PULL" --sys-name sys-foo 2>&1)"
code=$?
set -e

[[ "$code" -eq 0 ]] || fail "docs-pull 应成功：$out"
printf '%s\n' "$out" | grep -Fq 'SYNC_OK:' || fail "应输出 SYNC_OK"

assert_file_exists "$COMPANY/docs/system-sys-foo/sync-me.md"
grep -Fq 'https://example.com/org/sys-foo.git' "$COMPANY/docs/system-sys-foo/changelogs/CHANGE-LOG.md" \
  || fail "应写入 repository 作为 source"

pass "company: pull single sys syncs content and writes changelog"
