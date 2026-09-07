#!/usr/bin/env bash
# link 写入的 path 在 $HOME 下为 ~/ 前缀（集成：company → system）；并创建 system 槽位 + 写入 sys_* 与 repository
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
DOCS_LINK="$ROOT_DIR/scripts/docs-link.sh"
FAKEHOME="$TMP_DIR/fakehome"
COMPANY="$FAKEHOME/ws/company-repo"
SYSTEM="$FAKEHOME/ws/sys-foo"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

mkdir -p "$COMPANY/docs" "$SYSTEM/docs"
git -C "$COMPANY" init -q
git -C "$SYSTEM" init -q
git -C "$COMPANY" remote add origin "https://github.com/example/company-ea.git"
git -C "$SYSTEM" remote add origin "https://example.com/org/sys-foo.git"

cp -R "$ROOT_DIR/company/system-SYSNAME" "$COMPANY/docs/system-SYSNAME"

cat >"$COMPANY/.docsconfig" <<EOF
DOC_ROOT=docs
REPO_ROOT=$COMPANY
DOC_DIR=system
KNOWLEDGE_TYPE=company
AGENT_ROOT=$ROOT_DIR/agent
AGENT_DIRS=.cursor
EOF

cat >"$SYSTEM/.docsconfig" <<EOF
DOC_ROOT=docs
REPO_ROOT=$SYSTEM
DOC_DIR=system
KNOWLEDGE_TYPE=system
AGENT_ROOT=$ROOT_DIR/agent
AGENT_DIRS=.cursor
EOF

( cd "$COMPANY" && HOME="$FAKEHOME" "${BASH:-bash}" "$DOCS_LINK" --link --target "$SYSTEM" ) \
  || fail "docs-link --link 应成功"

assert_file_exists "$COMPANY/docs/knowledge-links.yaml"
grep -Fq 'path: "~/ws/sys-foo"' "$COMPANY/docs/knowledge-links.yaml" \
  || fail "path 应为 ~/ 前缀的 \$HOME 相对路径"
grep -Fq 'repository: "https://example.com/org/sys-foo.git"' "$COMPANY/docs/knowledge-links.yaml" \
  || fail "repository 应写入 target remote URL"
grep -Fq 'doc_dir: "system"' "$COMPANY/docs/knowledge-links.yaml" \
  || fail "doc_dir 应为 system"
grep -Fq 'sys_name: "sys-foo"' "$COMPANY/docs/knowledge-links.yaml" \
  || fail "sys_name 应写入"
grep -Fq 'sys_label: "sys-foo"' "$COMPANY/docs/knowledge-links.yaml" \
  || fail "sys_label 应写入"
assert_dir_exists "$COMPANY/docs/system-sys-foo"

assert_file_exists "$SYSTEM/docs/knowledge-parent.yaml"
grep -Fq 'knowledge_type: company' "$SYSTEM/docs/knowledge-parent.yaml" \
  || fail "parent.knowledge_type 应为 company"
grep -Fq 'repository: "https://github.com/example/company-ea.git"' \
  "$SYSTEM/docs/knowledge-parent.yaml" \
  || fail "parent.repository 应为源仓 origin"
grep -Fq 'doc_dir: "docs"' "$SYSTEM/docs/knowledge-parent.yaml" \
  || fail "parent.doc_dir 应为源 DOC_ROOT 相对仓库根"

pass "link 在 \$HOME 下写出 path: \"~/ws/sys-foo\" 并创建槽位与 knowledge-parent.yaml"
