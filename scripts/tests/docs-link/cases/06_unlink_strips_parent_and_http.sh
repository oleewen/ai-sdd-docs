#!/usr/bin/env bash
# unlink 删除目标 knowledge-parent.yaml，并将匹配 web_base 的跨层 HTTP 改为纯 ID
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
STUB="$SYSTEM/docs/knowledge/business/BD-EXAMPLE.md"
HREF='https://github.com/example/company-ea/blob/main/docs/knowledge/business/BD-EXAMPLE/BD-EXAMPLE.md'

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

run_link() {
  ( cd "$COMPANY" && HOME="$FAKEHOME" "${BASH:-bash}" "$DOCS_LINK" --link --target "$SYSTEM" )
}

run_unlink() {
  ( cd "$COMPANY" && HOME="$FAKEHOME" "${BASH:-bash}" "$DOCS_LINK" --unlink --target "$SYSTEM" )
}

run_link || fail "docs-link --link 应成功"
assert_file_exists "$SYSTEM/docs/knowledge-parent.yaml"
assert_file_exists "$COMPANY/docs/knowledge-links.yaml"
grep -Fq 'sys_name: "sys-foo"' "$COMPANY/docs/knowledge-links.yaml" \
  || fail "link 后清单应含 sys-foo"

mkdir -p "$(dirname "$STUB")"
cat >"$STUB" <<EOF
## 依据与证据

- 上游：[BD-EXAMPLE]($HREF)
- 其它：保留
EOF

run_unlink || fail "docs-link --unlink 应成功"

assert_file_not_exists "$SYSTEM/docs/knowledge-parent.yaml"
grep -Fq "$HREF" "$STUB" && fail "unlink 后不应残留匹配 web_base 的 HTTP"
grep -Fq '[BD-EXAMPLE]' "$STUB" && fail "unlink 后应去掉 Markdown 链，只留锚文本"
grep -Fq 'BD-EXAMPLE' "$STUB" || fail "unlink 后应保留实体 ID 文本"
grep -Fq '其它：保留' "$STUB" || fail "unlink 不得改写无关行"
if grep -Fq 'sys_name: "sys-foo"' "$COMPANY/docs/knowledge-links.yaml"; then
  fail "unlink 后源清单不应再含 sys-foo"
fi

pass "unlink 删除 knowledge-parent.yaml 并将跨层 HTTP 改为纯 ID"
