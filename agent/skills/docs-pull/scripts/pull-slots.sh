#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../../../agent/scripts/config-bootstrap.sh"

APP=""
SYS_NAME=""
ALL=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app)
      shift
      [[ -n "${1:-}" ]] || { printf '缺少 --app 值\n' >&2; exit 2; }
      APP="$1"
      shift
      ;;
    --sys-name)
      shift
      [[ -n "${1:-}" ]] || { printf '缺少 --sys-name 值\n' >&2; exit 2; }
      SYS_NAME="$1"
      shift
      ;;
    --all)
      ALL=1
      shift
      ;;
    -h|--help)
      printf '%s\n' "Usage: $0 [--app <app_name> | --sys-name <sys_name> | --all]"
      exit 0
      ;;
    *)
      printf '未知参数: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

validate_bootstrap_docsconfig

MODE="${KNOWLEDGE_TYPE:-}"
[[ "$MODE" == "system" || "$MODE" == "company" ]] || { printf '不支持的 KNOWLEDGE_TYPE: %s\n' "$MODE" >&2; exit 1; }

LINKS_FILE="${DOC_ROOT%/}/knowledge-links.yaml"
[[ -f "$LINKS_FILE" ]] || { printf '缺少 knowledge-links.yaml: %s\n' "$LINKS_FILE" >&2; exit 1; }

declare -a paths=() repos=() doc_dirs=() names=() labels=()
knowledge_links_load_into_arrays "$LINKS_FILE" paths repos doc_dirs names labels

if ! command -v rsync >/dev/null 2>&1; then
  printf '缺少 rsync，无法执行槽位同步\n' >&2
  exit 1
fi

expected_doc_dir=""
slot_prefix=""
name_flag=""
name_value=""

if [[ "$MODE" == "system" ]]; then
  expected_doc_dir="application"
  slot_prefix="application"
  name_flag="--app"
  name_value="$APP"
else
  expected_doc_dir="system"
  slot_prefix="system"
  name_flag="--sys-name"
  name_value="$SYS_NAME"
fi

if [[ "$ALL" -eq 0 ]]; then
  [[ -n "$name_value" ]] || { printf '缺少 %s 值\n' "$name_flag" >&2; exit 2; }
fi

select_indices() {
  local -n _out="${1:?}"
  local i
  _out=()
  if [[ "$ALL" -eq 1 ]]; then
    for i in "${!paths[@]}"; do
      [[ "${doc_dirs[i]:-}" == "$expected_doc_dir" ]] || continue
      _out+=("$i")
    done
    return 0
  fi
  for i in "${!paths[@]}"; do
    [[ "${doc_dirs[i]:-}" == "$expected_doc_dir" ]] || continue
    [[ "${names[i]:-}" == "$name_value" ]] || continue
    _out+=("$i")
    return 0
  done
  return 1
}

validate_link_fields() {
  local idx="${1:?}"
  [[ -n "${repos[idx]:-}" ]] || { printf 'link 缺少 repository（必填）: idx=%s\n' "$idx" >&2; return 1; }
  [[ -n "${paths[idx]:-}" ]] || { printf 'link 缺少 path（必填）: idx=%s\n' "$idx" >&2; return 1; }
  [[ "${doc_dirs[idx]:-}" == "$expected_doc_dir" ]] || { printf 'link doc_dir 不匹配: idx=%s\n' "$idx" >&2; return 1; }
  [[ -n "${names[idx]:-}" ]] || { printf 'link 缺少 name（必填）: idx=%s\n' "$idx" >&2; return 1; }
  [[ -n "${labels[idx]:-}" ]] || { printf 'link 缺少 label（必填）: idx=%s\n' "$idx" >&2; return 1; }
  return 0
}

append_change_log() {
  local slot_dir="${1:?}" slot_key="${2:?}" slot_name="${3:?}" source_repo="${4:?}" commit="${5:?}" scope="${6:?}" added="${7:?}" modified="${8:?}" deleted="${9:?}"
  local log_file synced_at
  log_file="${slot_dir%/}/changelogs/CHANGE-LOG.md"
  [[ -f "$log_file" ]] || { printf '缺少槽位 CHANGE-LOG.md: %s\n' "$log_file" >&2; return 1; }
  synced_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  {
    printf '\n'
    printf '## synced_at: %s\n' "$synced_at"
    printf '\n'
    printf -- '- %s: %s\n' "$slot_key" "$slot_name"
    printf -- '- source: %s\n' "$source_repo"
    printf -- '- commit: %s\n' "$commit"
    printf -- '- scope: %s\n' "$scope"
    printf -- '- stats: added=%s modified=%s deleted=%s\n' "$added" "$modified" "$deleted"
  } >>"$log_file"
}

pull_one() {
  local idx="${1:?}"
  validate_link_fields "$idx" || return 1

  local repo path_expanded name label target_cfg t_doc_root t_repo_root t_doc_dir t_agent_root t_agent_dirs t_ktype
  local source_dir slot_dir commit synced_at scope
  local rsync_stats added modified deleted

  repo="${repos[idx]}"
  path_expanded="$(knowledge_link_expand_stored_path "${paths[idx]}")"
  name="${names[idx]}"
  label="${labels[idx]}"

  [[ -d "$path_expanded" ]] || { printf 'path 不存在: %s\n' "$path_expanded" >&2; return 1; }
  [[ -d "$path_expanded/.git" || -f "$path_expanded/.git" ]] || { printf 'path 不是 Git 工作区: %s\n' "$path_expanded" >&2; return 1; }

  target_cfg="${path_expanded%/}/.docsconfig"
  [[ -f "$target_cfg" ]] || { printf '目标仓库缺少 .docsconfig: %s\n' "$target_cfg" >&2; return 1; }

  t_doc_root='' t_repo_root='' t_doc_dir='' t_agent_root='' t_agent_dirs='' t_ktype=''
  local saved_pwd="$PWD"
  cd "$path_expanded"
  docsconfig_read_into "$target_cfg" t_doc_root t_repo_root t_doc_dir t_agent_root t_agent_dirs t_ktype || { cd "$saved_pwd"; printf '无法解析目标 .docsconfig: %s\n' "$target_cfg" >&2; return 1; }
  cd "$saved_pwd"
  [[ -n "$t_doc_root" && -n "$t_doc_dir" && -n "$t_ktype" ]] || { printf '目标 .docsconfig 缺少 DOC_ROOT/DOC_DIR/KNOWLEDGE_TYPE: %s\n' "$target_cfg" >&2; return 1; }

  if [[ "$expected_doc_dir" == "application" ]]; then
    [[ "$t_ktype" == "application" ]] || { printf '目标 KNOWLEDGE_TYPE 不匹配（应为 application）: %s\n' "$t_ktype" >&2; return 1; }
  else
    [[ "$t_ktype" == "system" ]] || { printf '目标 KNOWLEDGE_TYPE 不匹配（应为 system）: %s\n' "$t_ktype" >&2; return 1; }
  fi

  # DOC_ROOT 即文档根（REPO_ROOT+DOC_DIR=DOC_ROOT）；禁止再拼 DOC_DIR，否则 docs/docs
  source_dir="${t_doc_root%/}"
  [[ -d "$source_dir" ]] || { printf '源目录不存在: %s\n' "$source_dir" >&2; return 1; }

  slot_dir="${DOC_ROOT%/}/${slot_prefix}-${name}"
  [[ -d "$slot_dir" ]] || { printf '槽位目录不存在，请先 docs-link 建联并创建槽位: %s\n' "$slot_dir" >&2; return 1; }

  rsync_stats="$(
    rsync -ani --delete \
      --exclude 'README.md' \
      --exclude 'index.md' \
      --exclude 'changelogs/' \
      "${source_dir%/}/" "${slot_dir%/}/" 2>/dev/null || true
  )"

  added="$(printf '%s\n' "$rsync_stats" | awk 'BEGIN{n=0} /^>f\\+\\+\\+\\+\\+\\+\\+\\+\\+/{n++} END{print n}')"
  modified="$(printf '%s\n' "$rsync_stats" | awk 'BEGIN{n=0} /^>f/ && $0 !~ /^>f\\+\\+\\+\\+\\+\\+\\+\\+\\+/{n++} END{print n}')"
  deleted="$(printf '%s\n' "$rsync_stats" | awk 'BEGIN{n=0} /^\\*deleting /{n++} END{print n}')"

  rsync -a --delete \
    --exclude 'README.md' \
    --exclude 'index.md' \
    --exclude 'changelogs/' \
    "${source_dir%/}/" "${slot_dir%/}/"

  commit="$(git -C "$path_expanded" rev-parse --short HEAD 2>/dev/null || printf 'unknown')"
  scope="DOC_DIR=${t_doc_dir}"

  slot_key="$([[ "$expected_doc_dir" == "application" ]] && printf 'app_name' || printf 'sys_name')"
  append_change_log "$slot_dir" "$slot_key" "$name" "$repo" "$commit" "$scope" "$added" "$modified" "$deleted" || return 1

  printf 'SYNC_OK: %s (%s)\n' "$name" "$label"
  return 0
}

declare -a indices=()
if ! select_indices indices; then
  printf '未找到匹配的 link（doc_dir=%s, %s=%s）\n' "$expected_doc_dir" "$name_flag" "$name_value" >&2
  exit 1
fi

failures=()
for idx in "${indices[@]}"; do
  if ! pull_one "$idx"; then
    failures+=("$idx")
  fi
done

if [[ "${#failures[@]}" -gt 0 ]]; then
  printf 'FAILED: %s\n' "${failures[*]}" >&2
  exit 1
fi
