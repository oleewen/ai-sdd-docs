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

SYSTEM="$TMP_DIR/system"
APP="$TMP_DIR/app-foo"

mkdir -p "$SYSTEM/docs" "$APP/docs"
git -C "$SYSTEM" init -q
git -C "$APP" init -q
git -C "$APP" remote add origin "https://example.com/org/app-foo.git"

# 联邦侧：槽位与 knowledge-links 落在 DOC_ROOT 下
cat >"$SYSTEM/.docsconfig" <<EOF
DOC_ROOT=docs
REPO_ROOT=$SYSTEM
DOC_DIR=docs
KNOWLEDGE_TYPE=system
AGENT_ROOT=$ROOT_DIR/agent
AGENT_DIRS=.cursor
EOF

# 目标应用仓：DOC_ROOT 即正文根（REPO_ROOT+DOC_DIR=DOC_ROOT）
cat >"$APP/.docsconfig" <<EOF
DOC_ROOT=docs
REPO_ROOT=$APP
DOC_DIR=docs
KNOWLEDGE_TYPE=application
AGENT_ROOT=$ROOT_DIR/agent
AGENT_DIRS=.cursor
EOF

mkdir -p "$SYSTEM/docs/application-app-foo/changelogs"
echo "# CHANGE LOG - APPNAME" >"$SYSTEM/docs/application-app-foo/changelogs/CHANGE-LOG.md"
echo "# slot wrapper" >"$SYSTEM/docs/application-app-foo/README.md"
echo "# slot index" >"$SYSTEM/docs/application-app-foo/index.md"

echo "content" >"$APP/docs/sync-me.md"

cat >"$SYSTEM/docs/knowledge-links.yaml" <<EOF
links:
  - repository: "https://example.com/org/app-foo.git"
    path: "$APP"
    doc_dir: "application"
    app_name: "app-foo"
    app_label: "app-foo"
EOF

git -C "$APP" add .
git -C "$APP" commit -m "init app docs" -q

set +e
out="$(cd "$SYSTEM" && "${BASH:-bash}" "$PULL" --app app-foo 2>&1)"
code=$?
set -e

[[ "$code" -eq 0 ]] || fail "docs-pull 应成功：$out"
printf '%s\n' "$out" | grep -Fq 'SYNC_OK:' || fail "应输出 SYNC_OK"

assert_file_exists "$SYSTEM/docs/application-app-foo/sync-me.md"
grep -Fq 'https://example.com/org/app-foo.git' "$SYSTEM/docs/application-app-foo/changelogs/CHANGE-LOG.md" \
  || fail "应写入 repository 作为 source"

pass "system: pull single app syncs content and writes changelog"
