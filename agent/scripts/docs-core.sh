#!/usr/bin/env bash
#
# docs-core.sh — 共享路径、.docsconfig 工具与 knowledge-links.yaml 只读解析（供 scripts/*-config.sh source）
#

expand_tilde() {
  local p="${1:-}"
  if [[ "$p" == '~' ]]; then
    printf '%s\n' "${HOME:-}"
  elif [[ "$p" =~ ^~/ ]]; then
    printf '%s\n' "${HOME:-}/${p:2}"
  else
    printf '%s\n' "$p"
  fi
}

abs_path() {
  local p
  p="$(expand_tilde "${1:-}")"
  [[ -n "$p" ]] || return 1
  [[ "$p" == /* ]] || p="$PWD/$p"

  if [[ -d "$p" ]]; then
    (cd -P "$p" 2>/dev/null && pwd)
  else
    local dir base
    dir="$(dirname "$p")"
    base="$(basename "$p")"
    dir="$(cd -P "$dir" 2>/dev/null && pwd || printf '%s' "$dir")"
    printf '%s/%s\n' "$dir" "$base"
  fi
}

strip_trailing_slash() {
  local p="${1:-}"
  while [[ "$p" != '/' && "$p" == */ ]]; do
    p="${p%/}"
  done
  printf '%s\n' "$p"
}

if [[ -n "${_AGENT_SHARED_DOCS_CONFIG_LOADED:-}" ]]; then
  return 0
fi
# 不可 readonly：联邦仓会按 AGENT_* 再 source 另一份副本，须能 unset 后重新加载。
_AGENT_SHARED_DOCS_CONFIG_LOADED=1

readonly SDX_MIN_BASH_VERSION=5

require_bash5() {
  if (( BASH_VERSINFO[0] < SDX_MIN_BASH_VERSION )); then
    printf '[FATAL] 需要 Bash %s+，当前版本: %s\n' "$SDX_MIN_BASH_VERSION" "$BASH_VERSION" >&2
    exit 1
  fi
}
require_bash5

sdx_log()   { printf '%s\n'       "$*" >&2; }
sdx_info()  { printf '信息: %s\n'  "$*" >&2; }
sdx_warn()  { printf '警告: %s\n'  "$*" >&2; }
sdx_error() { printf '错误: %s\n' "$*" >&2; exit 1; }

sdx_have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

sdx_have_perl() {
  sdx_have_cmd perl
}

# 与 sdx_run_or_dry / sdx_sync_dir / sdx_io_* 一致：DRY_RUN、CFG[dry_run] 或 SDX_IO_DRY_RUN
sdx_dry_run_enabled() {
  [[ "${DRY_RUN:-${CFG[dry_run]:-0}}" == '1' || "${SDX_IO_DRY_RUN:-0}" == '1' ]]
}

sdx_run_or_dry() {
  if sdx_dry_run_enabled; then
    sdx_log "[dry-run] $*"
  else
    "$@"
  fi
}

sdx_ensure_dir() { sdx_run_or_dry mkdir -p "$1"; }

sdx_sync_dir() {
  local src="$1" dst="$2"
  shift 2

  [[ -d "$src" ]] || return 0
  if sdx_dry_run_enabled; then
    sdx_log "[dry-run] 同步目录: $src → $dst"
    return 0
  fi
  sdx_ensure_dir "$dst"
  if sdx_have_cmd rsync; then
    rsync -a --delete "$@" "$src"/ "$dst"/
  else
    sdx_warn "未检测到 rsync，使用 cp -R（无法完全排除或增量同步；建议安装 rsync）"
    [[ -n "$dst" && "$dst" != '/' ]] || {
      sdx_error "sdx_sync_dir 目标目录非法: '$dst'"
    }
    rm -rf "$dst"
    sdx_ensure_dir "$(dirname "$dst")"
    cp -R "$src" "$dst"
  fi
}

sdx_io_should_overwrite() {
  local target="$1"
  sdx_dry_run_enabled && return 0
  [[ "${SDX_IO_FORCE:-0}" == '1' ]] && return 0
  case "${SDX_IO_CONFLICT_MODE:-}" in
    overwrite_all) return 0 ;;
    skip_all)      return 1 ;;
  esac
  [[ ! -t 0 ]] && return 0
  sdx_log "目标已存在：$target"
  printf '1) 覆盖 / 2) 跳过 / 3) 全部覆盖 / 4) 全部跳过 [默认 1，Esc 退出]：' >&2
  local key='' key2=''
  IFS= read -rsn1 key || { sdx_log "已取消"; return 2; }
  if [[ "$key" == $'\e' ]]; then
    if IFS= read -rsn1 -t 0.05 key2 2>/dev/null; then
      sdx_log "无效选择，默认覆盖"; return 0
    fi
    sdx_log "已取消（Esc）" >&2
    return 2
  fi
  case "$key" in
    $'\n'|$'\r'|1) return 0 ;;
    2) return 1 ;;
    3) SDX_IO_CONFLICT_MODE='overwrite_all'; return 0 ;;
    4) SDX_IO_CONFLICT_MODE='skip_all'; return 1 ;;
    *) sdx_log "无效选择，默认覆盖"; return 0 ;;
  esac
}

sdx_io_copy_file() {
  local src="$1" dst="$2"
  if sdx_dry_run_enabled; then
    sdx_log "[dry-run] 拷贝: $src → $dst"; return 0
  fi
  if [[ -e "$dst" ]]; then
    local _ow=0
    sdx_io_should_overwrite "$dst" || _ow=$?
    [[ "$_ow" -eq 2 ]] && exit 130
    [[ "$_ow" -eq 1 ]] && { sdx_log "[skip] $dst"; return 1; }
    if [[ -n "${SDX_IO_BACKUP_FN:-}" ]] && declare -f "$SDX_IO_BACKUP_FN" >/dev/null; then
      "$SDX_IO_BACKUP_FN" "$dst"
    fi
  fi
  sdx_ensure_dir "$(dirname "$dst")"
  cp "$src" "$dst"
}

sdx_backup_rel_under_root() {
  local repo_root="${1:?}" existing="${2:?}"
  existing="$(abs_path "$existing")"
  repo_root="$(strip_trailing_slash "$(abs_path "$repo_root")")"
  if [[ "$existing" == "$repo_root"/* ]]; then
    printf '%s' "${existing#"$repo_root"/}"
  else
    printf '%s' "${existing#/}"
  fi
}

readonly SDX_GIT_REPO_URL='https://github.com/oleewen/ai-knowledge.git'
readonly SDX_GIT_DEFAULT_REF='HEAD'

sdx_docs_bootstrap_get_repo_url() {
  printf '%s' "${GIT_REPO_URL:-$SDX_GIT_REPO_URL}"
}

sdx_docs_bootstrap_get_ref() {
  printf '%s' "${GIT_REF:-$SDX_GIT_DEFAULT_REF}"
}

sdx_docs_bootstrap_get_tmpdir() {
  local tmpdir="${TMPDIR:-/tmp}"
  [[ -d "$tmpdir" ]] || tmpdir='/tmp'
  printf '%s' "$tmpdir"
}

sdx_docs_bootstrap_gen_clone_dir() {
  printf '%s/ai-knowledge-%s' "${1:?tmpdir}" "$$"
}

docsconfig_format_root_for_write() {
  local p home
  p="$(strip_trailing_slash "$(abs_path "${1:?}")")"
  [[ -n "${HOME:-}" ]] || { printf '%s\n' "$p"; return 0; }
  home="$(strip_trailing_slash "$(abs_path "$HOME")")"
  [[ -n "$home" ]] || { printf '%s\n' "$p"; return 0; }

  if [[ "$p" == "$home" ]]; then
    printf '~\n'
  elif [[ "$p" == "$home"/* ]]; then
    printf '~/%s\n' "${p#"$home"/}"
  else
    printf '%s\n' "$p"
  fi
}

docsconfig_normalize_root_value() {
  local v="${1:-}"
  v="${v%$'\r'}"
  printf '%s' "$(abs_path "$v")"
}

docsconfig_repo_root_from_doc_root() {
  local doc_root="${1:?doc_root}" dr gr
  dr="$(cd -P "$doc_root" 2>/dev/null && pwd)" || return 0
  gr="$(git -C "$dr" rev-parse --show-toplevel 2>/dev/null || true)"
  if [[ -n "$gr" && "$(dirname "$dr")" == "$gr" ]]; then
    printf '%s\n' "$gr"
    return 0
  fi
  cd -P "$(dirname "$doc_root")" 2>/dev/null && pwd || true
}

docsconfig_repo_root_fallback_from_doc_root() {
  docsconfig_repo_root_from_doc_root "$@"
}

docsconfig_find_repo_root() {
  local pwd_root d i
  pwd_root="$(git -C "${PWD}" rev-parse --show-toplevel 2>/dev/null || true)"
  d="$(cd -P "$PWD" 2>/dev/null && pwd)" || return 1

  for ((i = 0; i < 32; i++)); do
    [[ -f "$d/.docsconfig" ]] && {
      printf '%s' "$d"
      return 0
    }
    [[ -n "$pwd_root" && "$d" == "$pwd_root" ]] && break
    [[ "$d" == "/" ]] && break
    d="$(dirname "$d")"
  done
  return 1
}

docsconfig_find_path() {
  local repo_root
  repo_root="$(docsconfig_find_repo_root)" || return 1
  printf '%s/.docsconfig' "$repo_root"
}

docsconfig_validate_owner_matches_repo_root() {
  local config_owner_root="${1:?config_owner_root}"
  local repo_root="${2:?repo_root}"
  local owner_abs repo_abs

  owner_abs="$(cd -P "$config_owner_root" 2>/dev/null && pwd)" || return 1
  repo_abs="$(cd -P "$repo_root" 2>/dev/null && pwd)" || return 1
  if [[ "$owner_abs" != "$repo_abs" ]]; then
    printf '[docsconfig] 配置漂移：.docsconfig 位于 %s，但 REPO_ROOT=%s\n' \
      "$owner_abs" "$repo_abs" >&2
    return 1
  fi
}

docsconfig_doc_dir_from_roots() {
  local repo_root="${1:?repo_root}" doc_root="${2:?doc_root}"
  local rr dr
  rr="$(cd -P "$repo_root" 2>/dev/null && pwd)" || {
    printf '[docsconfig] 无法解析 REPO_ROOT: %s\n' "$repo_root" >&2
    return 1
  }
  dr="$(cd -P "$doc_root" 2>/dev/null && pwd)" || {
    printf '[docsconfig] 无法解析 DOC_ROOT: %s\n' "$doc_root" >&2
    return 1
  }
  case "$dr" in
    "$rr") printf '.\n' ;;
    "$rr"/*) printf '%s\n' "${dr#"$rr"/}" ;;
    *)
      printf '[docsconfig] DOC_ROOT 不在 REPO_ROOT 下: %s vs %s\n' "$dr" "$rr" >&2
      return 1
      ;;
  esac
}

sdx_docs_backup_path_to_init() {
  local repo_root="${1:?}" existing="${2:?}" stamp="${3:-}" dry_run="${4:-0}"
  local backup_root rel backup_target
  existing="$(abs_path "$existing")"
  repo_root="$(strip_trailing_slash "$(abs_path "$repo_root")")"
  [[ -e "$existing" ]] || return 0
  [[ -n "$stamp" ]] || stamp="$(date +%Y-%m-%d_%H-%M-%S)"
  backup_root="${repo_root}/.docs-init/${stamp}"

  rel="$(sdx_backup_rel_under_root "$repo_root" "$existing")"

  backup_target="${backup_root}/${rel}"
  if [[ -e "$backup_target" ]]; then
    local i=1
    while [[ -e "${backup_target}.__${i}" ]]; do (( i++ )); done
    backup_target="${backup_target}.__${i}"
  fi

  if [[ "$dry_run" == '1' ]]; then
    sdx_info "[dry-run] 将备份：$existing → $backup_target"
    return 0
  fi

  mkdir -p "$(dirname "$backup_target")" 2>/dev/null || true
  mv "$existing" "$backup_target"
  sdx_info "已备份：$existing → $backup_target"
}

# 静默：是否为合法 KNOWLEDGE_TYPE（与 validate_type / docsconfig_write 一致）
docsconfig_knowledge_type_is_valid() {
  local v="${1:-}"
  [[ "$v" == 'application' || "$v" == 'system' || "$v" == 'company' ]]
}

docsconfig_validate_knowledge_type() {
  local v="${1:-}"
  docsconfig_knowledge_type_is_valid "$v" && return 0
  printf '[docsconfig] 非法 KNOWLEDGE_TYPE: %s（允许: application system company）\n' "$v" >&2
  return 1
}

# 与 docsconfig_knowledge_type_is_valid 允许集合一致（供 *-config 枚举/文档对齐）
readonly -a SDX_SUPPORTED_KNOWLEDGE_TYPES=(application system company)
readonly -a SDX_SUPPORTED_AGENTS=(cursor trae claude kiro codex)

sdx_agents_normalize() {
  local agents_str="${1:-}"
  if [[ "$agents_str" == 'all' ]]; then
    printf '%s' "${SDX_SUPPORTED_AGENTS[*]}"
    return 0
  fi
  local -a agents normalized
  local -A seen
  IFS=', ' read -ra agents <<< "$agents_str"
  local agent
  for agent in "${agents[@]}"; do
    [[ -z "$agent" ]] && continue
    [[ -n "${seen[$agent]+x}" ]] && continue
    seen["$agent"]=1
    normalized+=("$agent")
  done
  printf '%s' "${normalized[*]}"
}

sdx_agents_validate() {
  local agents_str="${1:-}"
  local -a agents
  IFS=', ' read -ra agents <<< "$agents_str"
  local agent
  for agent in "${agents[@]}"; do
    [[ -z "$agent" ]] && continue
    [[ "$agent" == 'all' ]] && return 0
    [[ " ${SDX_SUPPORTED_AGENTS[*]} " == *" $agent "* ]] || return 1
  done
  return 0
}

# 打印 .docsconfig 正文键值（不含文件头）；参数：dr rr doc_dir knowledge_type agent_root agent_dirs
docsconfig_print_kv_block() {
  local dr="$1" rr="$2" doc_dir="$3" knowledge_type="$4" agent_root="$5" agent_dirs="$6"
  local ar
  printf 'DOC_ROOT=%s\nREPO_ROOT=%s\nDOC_DIR=%s\n' "$dr" "$rr" "$doc_dir"
  [[ -n "$knowledge_type" ]] && printf 'KNOWLEDGE_TYPE=%s\n' "$knowledge_type"
  if [[ -n "$agent_root" ]]; then
    ar="$(docsconfig_format_root_for_write "$agent_root")"
    printf 'AGENT_ROOT=%s\nAGENT_DIRS="%s"\n' "$ar" "$agent_dirs"
  fi
}

docsconfig_write() {
  local repo_root="${1:?repo_root}"
  local doc_root="${2:?doc_root}"
  local doc_dir="${3:?doc_dir}"
  local dry="${4:-0}"
  local agent_root_in="${5:-}"
  local agent_dirs_in="${6:-}"
  local knowledge_type_in="${7:-}"

  if [[ -n "$agent_root_in" && -z "$agent_dirs_in" && -z "$knowledge_type_in" ]]; then
    case "$agent_root_in" in
      application|system|company)
        knowledge_type_in="$agent_root_in"
        agent_root_in=''
        ;;
    esac
  fi

  local out rr dr
  out="$(strip_trailing_slash "$(abs_path "$repo_root")")/.docsconfig"
  rr="$(docsconfig_format_root_for_write "$repo_root")"
  dr="$(docsconfig_format_root_for_write "$doc_root")"

  if [[ -n "$knowledge_type_in" ]]; then
    docsconfig_validate_knowledge_type "$knowledge_type_in" || return 1
  fi

  if [[ "$dry" == '1' ]]; then
    printf 'Would write %s:\n' "$out"
    docsconfig_print_kv_block "$dr" "$rr" "$doc_dir" "$knowledge_type_in" "$agent_root_in" "$agent_dirs_in"
    return 0
  fi

  umask 022
  {
    docsconfig_print_kv_block "$dr" "$rr" "$doc_dir" "$knowledge_type_in" "$agent_root_in" "$agent_dirs_in"
  } >"$out"
}

docsconfig_read_into() {
  local path="${1:?path}"
  local -n _doc="${2:?}"
  local -n _repo="${3:?}"
  local -n _ddir="${4:?}"
  _doc=''; _repo=''; _ddir=''
  [[ -f "$path" ]] || return 1

  # 局部名须避开调用方 nameref 目标（如 raw_ar / AGENT_ROOT），否则 Bash 会写空调用方变量。
  local _dc_raw_doc='' _dc_raw_repo='' _dc_raw_ddir='' _dc_raw_ar='' _dc_raw_ads='' _dc_raw_kt=''
  local line k v
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    case "$line" in
      DOC_ROOT=*|REPO_ROOT=*|DOC_DIR=*|AGENT_ROOT=*|AGENT_DIRS=*|KNOWLEDGE_TYPE=*)
        k="${line%%=*}"
        v="${line#*=}"
        v="${v%$'\r'}"
        if [[ "$k" == 'AGENT_DIRS' && ${#v} -ge 2 && "${v:0:1}" == '"' && "${v: -1}" == '"' ]]; then
          v="${v:1:${#v}-2}"
        fi
        case "$k" in
          DOC_ROOT) _dc_raw_doc="$v" ;;
          REPO_ROOT) _dc_raw_repo="$v" ;;
          DOC_DIR) _dc_raw_ddir="$v" ;;
          AGENT_ROOT) _dc_raw_ar="$v" ;;
          AGENT_DIRS) _dc_raw_ads="$v" ;;
          KNOWLEDGE_TYPE) _dc_raw_kt="$v" ;;
        esac
        ;;
    esac
  done <"$path"

  [[ -n "$_dc_raw_doc" ]] && _doc="$(docsconfig_normalize_root_value "$_dc_raw_doc")"
  [[ -n "$_dc_raw_repo" ]] && _repo="$(docsconfig_normalize_root_value "$_dc_raw_repo")"
  _ddir="$_dc_raw_ddir"

  if (( $# >= 6 )); then
    local -n _aroot="${5:?}"
    local -n _adirs="${6:?}"
    _aroot=''
    [[ -n "$_dc_raw_ar" ]] && _aroot="$(docsconfig_normalize_root_value "$_dc_raw_ar")"
    _adirs="$_dc_raw_ads"
  fi
  if (( $# >= 7 )); then
    local -n _ktype="${7:?}"
    _ktype="$_dc_raw_kt"
  fi
  return 0
}

sdx_is_text_file() {
  local f="$1"
  case "$f" in
    *.md|*.yaml|*.yml|*.json|*.jsonl|*.txt|*.sh|*.gitignore|*.html|*.css|*.js|*.toml)
      return 0 ;;
  esac
  if sdx_have_cmd file; then
    local mt
    mt="$(file -b --mime-type "$f" 2>/dev/null || true)"
    [[ "$mt" == text/* || "$mt" == application/json || "$mt" == *yaml* || "$mt" == *json* ]] && return 0
  fi
  return 1
}

sdx_rewrite_agent_path_segment_in_file() {
  local file="$1" agent_slash="${2:?}"
  [[ -f "$file" ]] && sdx_is_text_file "$file" || return 0
  grep -q 'agent/' "$file" 2>/dev/null || return 0
  sdx_have_cmd perl || return 0
  if ! SDX_AGENT_SLASH="$agent_slash" \
    perl -CSD -i -pe 'BEGIN { die "SDX_AGENT_SLASH unset\n" unless defined $ENV{SDX_AGENT_SLASH} && length $ENV{SDX_AGENT_SLASH} } s{\bagent/}{$ENV{SDX_AGENT_SLASH}}g' \
    "$file" 2>/dev/null; then
    sdx_warn "重写 agent/ 路径失败：$file"
  fi
}

# 遍历 root 下待重写路径的文件：排除常见依赖/缓存/版本库目录，避免 ~/.cursor/skills 等目录残留导致 find 极慢或“假死”
sdx_rewrite_agent_path_segment_in_tree() {
  local root="$1" agent_slash="${2:?}"
  [[ -d "$root" ]] || return 0
  sdx_info "  重写 agent/ 路径引用（跳过 node_modules/.git 等）: ${root}"
  local f
  while IFS= read -r -d '' f; do
    sdx_rewrite_agent_path_segment_in_file "$f" "$agent_slash"
  done < <(
    find "$root" \
      \( -name node_modules -o -name .git -o -name __pycache__ -o -name .venv -o -name .cache -o -name dist -o -name build -o -name target \) \
      -prune -o -type f \( \
        -name '*.md' -o -name '*.yaml' -o -name '*.yml' -o -name '*.json' -o -name '*.jsonl' \
        -o -name '*.txt' -o -name '*.sh' -o -name '*.gitignore' -o -name '*.html' -o -name '*.css' \
        -o -name '*.js' -o -name '*.toml' \
      \) -print0 2>/dev/null || true
  )
}

# 自 start 目录向上找首个含 relative_path 文件的目录，打印该目录绝对路径
sdx_find_upward_with_file() {
  local relative_path="${1:?}" start d
  shift
  [[ $# -gt 0 ]] || set -- "${PWD}"
  local s
  for s in "$@"; do
    d="$(cd -P "$s" 2>/dev/null && pwd -P)" || continue
    while [[ -n "$d" && "$d" != "/" ]]; do
      [[ -f "$d/$relative_path" ]] && {
        printf '%s\n' "$d"
        return 0
      }
      d="$(dirname "$d")"
    done
  done
  return 1
}

# 解析 docs-core.sh 绝对路径（不 source）；顺序见 agent/skills/docs-push/references/parameters.md
sdx_resolve_docs_core_path() {
  local hint="${1:-${PWD}}" d home="${HOME:-}" dc

  if [[ -n "${DOCS_CORE_SH:-}" ]]; then
    [[ -f "$DOCS_CORE_SH" ]] || return 1
    abs_path "$DOCS_CORE_SH"
    return 0
  fi

  for dc in \
    "${hint}/../agent/scripts/docs-core.sh" \
    "${hint}/agent/scripts/docs-core.sh" \
    "${hint}/../../../scripts/docs-core.sh"; do
    if [[ -f "$dc" ]]; then
      abs_path "$dc"
      return 0
    fi
  done

  if [[ -n "$home" ]]; then
    for dc in \
      "${home}/.agents/scripts/docs-core.sh" \
      "${home}/.cursor/scripts/docs-core.sh" \
      "${home}/.trae/scripts/docs-core.sh" \
      "${home}/.claude/scripts/docs-core.sh" \
      "${home}/.kiro/scripts/docs-core.sh" \
      "${home}/.codex/scripts/docs-core.sh"; do
      if [[ -f "$dc" ]]; then
        abs_path "$dc"
        return 0
      fi
    done
  fi

  d="$(cd -P "$hint" 2>/dev/null && pwd -P || printf '%s' "$hint")"
  while [[ -n "$d" && "$d" != "/" ]]; do
    if [[ -f "$d/agent/scripts/docs-core.sh" ]]; then
      abs_path "$d/agent/scripts/docs-core.sh"
      return 0
    fi
    d="$(dirname "$d")"
  done

  d="$(pwd -P 2>/dev/null || pwd)"
  while [[ -n "$d" && "$d" != "/" ]]; do
    if [[ -f "$d/agent/scripts/docs-core.sh" ]]; then
      abs_path "$d/agent/scripts/docs-core.sh"
      return 0
    fi
    d="$(dirname "$d")"
  done

  if [[ -n "${AIK_ROOT:-}" && -f "${AIK_ROOT}/agent/scripts/docs-core.sh" ]]; then
    abs_path "${AIK_ROOT}/agent/scripts/docs-core.sh"
    return 0
  fi
  return 1
}

# 同源（含符号链接同一 inode）则跳过；否则 unset 哨兵后 source。
_sdx_docs_core_source_if_needed() {
  local target="${1:?}"
  local already="${2:-}"
  [[ -f "$target" ]] || return 1
  if [[ -n "$already" && -e "$already" && "$target" -ef "$already" ]]; then
    return 0
  fi
  unset _AGENT_SHARED_DOCS_CONFIG_LOADED
  # shellcheck source=/dev/null
  source "$target"
}

sdx_source_docs_core_from_layout() {
  local link_config_dir="${1:?}"
  local core bootstrap_used=''
  core="${link_config_dir}/../agent/scripts/docs-core.sh"
  if [[ -f "$core" ]]; then
    # shellcheck source=/dev/null
    source "$core"
    return 0
  fi

  bootstrap_used=''
  if declare -f sdx_resolve_docs_core_path >/dev/null 2>&1; then
    bootstrap_used="$(sdx_resolve_docs_core_path "$link_config_dir" 2>/dev/null || true)"
  else
    for bootstrap_used in \
      "${HOME}/.cursor/scripts/docs-core.sh" \
      "${HOME}/.trae/scripts/docs-core.sh" \
      "${HOME}/.claude/scripts/docs-core.sh" \
      "${HOME}/.kiro/scripts/docs-core.sh" \
      "${HOME}/.codex/scripts/docs-core.sh"; do
      [[ -f "$bootstrap_used" ]] && break
      bootstrap_used=''
    done
  fi
  if [[ -n "$bootstrap_used" && -f "$bootstrap_used" ]]; then
    if ! declare -f abs_path >/dev/null 2>&1; then
      _sdx_docs_core_source_if_needed "$bootstrap_used"
    fi
  elif ! declare -f abs_path >/dev/null 2>&1; then
    printf '错误: 未找到中央库 %s，且未安装 Agent scripts（~/.cursor/scripts/docs-core.sh）。\n' \
      "${link_config_dir}/../agent/scripts/docs-core.sh" >&2
    return 1
  fi

  local repo_root cfg _layout_ar _layout_ads line v
  repo_root="$(cd "$(dirname "${link_config_dir}")" && pwd)"
  cfg="${repo_root}/.docsconfig"
  if [[ ! -f "$cfg" ]]; then
    printf '错误: 未找到 %s，且目标工程根无 .docsconfig（%s）。请使用中央库 clone 执行 docs-link，或在目标工程先 docs-install --scope=config 并安装 agent 脚本（含 docs-core.sh）。\n' \
      "${link_config_dir}/../agent/scripts/docs-core.sh" "$cfg" >&2
    return 1
  fi

  _layout_ar=''
  _layout_ads=''
  if declare -f docsconfig_read_into >/dev/null 2>&1; then
    local _cfg_dr _cfg_rr _cfg_dd
    docsconfig_read_into "$cfg" _cfg_dr _cfg_rr _cfg_dd _layout_ar _layout_ads || return 1
  else
    local v
    while IFS= read -r line || [[ -n "$line" ]]; do
      [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
      case "$line" in
        AGENT_ROOT=*)
          _layout_ar="${line#*=}"
          _layout_ar="${_layout_ar%$'\r'}"
          ;;
        AGENT_DIRS=*)
          v="${line#*=}"
          v="${v%$'\r'}"
          if [[ ${#v} -ge 2 && "${v:0:1}" == '"' && "${v: -1}" == '"' ]]; then
            v="${v:1:${#v}-2}"
          fi
          _layout_ads="$v"
          ;;
      esac
    done <"$cfg"
  fi

  local ar_base='' resolved_core=''
  if [[ -n "$_layout_ar" ]]; then
    ar_base="$(abs_path "$_layout_ar")"
    resolved_core="${ar_base}/scripts/docs-core.sh"
    if [[ -f "$resolved_core" ]]; then
      _sdx_docs_core_source_if_needed "$resolved_core" "$bootstrap_used"
      return 0
    fi
  fi

  local d d_base
  for d in $_layout_ads; do
    [[ -z "$d" ]] && continue
    d_base="$d"
    if [[ -n "$ar_base" && "$d_base" != /* && "$d_base" != "~"* ]]; then
      d_base="${ar_base}/${d_base}"
    fi
    resolved_core="$(abs_path "$d_base")/scripts/docs-core.sh"
    if [[ -f "$resolved_core" ]]; then
      _sdx_docs_core_source_if_needed "$resolved_core" "$bootstrap_used"
      return 0
    fi
  done

  printf '错误: .docsconfig 已存在（%s），但 AGENT_ROOT/AGENT_DIRS 下均未找到 scripts/docs-core.sh。请执行 agent-install.sh --scope=sh 或等价安装。\n' "$cfg" >&2
  return 1
}

# knowledge-links.yaml（只读解析）

_yaml_unquote() {
  local v="${1:-}"
  v="${v#\"}"; v="${v%\"}"
  v="${v#\'}"; v="${v%\'}"
  printf '%s' "$v"
}

# 与 identity 解析一致：判定是否为 Git 远端 URL 形态（path 字段禁止写入此类串）
knowledge_link_value_looks_like_git_remote() {
  [[ "${1:-}" =~ ^(git@|ssh://|https://|http://) ]]
}

# path 字段禁止为远程 URL 形态（须写在 repository）
knowledge_links_validate_stored_path_field() {
  local p="${1:?}" src="${2:?}"
  [[ -n "$p" ]] || sdx_error "knowledge-links.yaml 条目缺少 path 或 path 为空: $src"
  if knowledge_link_value_looks_like_git_remote "$p"; then
    sdx_error "knowledge-links.yaml: path 不得为远程 URL（已废弃）。请将远端写入 repository，path 改为 ~/…、~/ 或本机绝对路径（兼容旧：无 ~ 的 \$HOME 相对片段）: $src"
  fi
}

# 将登记 path 展开为绝对路径（~/…、~、/ 绝对路径走 abs_path；否则视为相对 $HOME 的旧形态并拼 $HOME）
knowledge_link_expand_stored_path() {
  local p="${1:?}" home
  if [[ "$p" == /* || "$p" == '~' || "$p" =~ ^~/ ]]; then
    abs_path "$p"
    return 0
  fi
  home="${HOME:-}"
  [[ -n "$home" ]] || sdx_error "未设置 HOME，无法展开相对 path: $p"
  abs_path "${home%/}/$p"
}

# 读入 knowledge-links.yaml 填入数组（下标对齐）；非法旧形态 path=URL 时报错退出
knowledge_links_load_into_arrays() {
  local f="${1:?}"
  local -n _paths="${2:?}"
  local -n _repos="${3:?}"
  local -n _dirs="${4:?}"
  local -n _apps="${5:?}"
  local -n _labels="${6:?}"
  local line key val path="" repo="" doc_dir="" app_name="" app_label="" sys_name="" sys_label=""

  _paths=()
  _repos=()
  _dirs=()
  _apps=()
  _labels=()

  [[ -f "$f" ]] || return 0

  flush_pending() {
    if [[ -n "$path" ]]; then
      knowledge_links_validate_stored_path_field "$path" "$f"
      _paths+=("$path")
      _repos+=("${repo:-}")
      _dirs+=("${doc_dir:-}")
      if [[ "$doc_dir" == 'system' ]]; then
        _apps+=("${sys_name:-}")
        _labels+=("${sys_label:-}")
      else
        _apps+=("${app_name:-}")
        _labels+=("${app_label:-}")
      fi
    elif [[ -n "$repo$doc_dir$app_name$app_label$sys_name$sys_label" ]]; then
      sdx_error "knowledge-links.yaml 中存在未写完的条目（有 repository/doc_dir/app_name/app_label/sys_name/sys_label 但缺少 path）: $f"
    fi
    path='' repo='' doc_dir='' app_name='' app_label='' sys_name='' sys_label=''
  }

  set_kv() {
    case "${1:?}" in
      path) path="$2" ;;
      repository) repo="$2" ;;
      doc_dir) doc_dir="$2" ;;
      app_name) app_name="$2" ;;
      app_label) app_label="$2" ;;
      sys_name) sys_name="$2" ;;
      sys_label) sys_label="$2" ;;
      *) ;;
    esac
  }

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "${line//[[:space:]]/}" ]] && continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    if [[ "$line" =~ ^[[:space:]]*-[[:space:]]+([a-z_]+):[[:space:]]*(.*)$ ]]; then
      key="${BASH_REMATCH[1]}"
      val="$(_yaml_unquote "${BASH_REMATCH[2]}")"
      flush_pending
      set_kv "$key" "$val"
    elif [[ "$line" =~ ^[[:space:]]{4}([a-z_]+):[[:space:]]*(.*)$ ]]; then
      key="${BASH_REMATCH[1]}"
      val="$(_yaml_unquote "${BASH_REMATCH[2]}")"
      set_kv "$key" "$val"
    fi
  done <"$f"
  flush_pending
}
