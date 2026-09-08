#!/usr/bin/env bash
# agent-install.sh — 安装 Agent（scripts / rules / skills / hooks）并按需更新 .docsconfig 中的 AGENT_*
#
# 配置面：source 同目录 agent-config.sh。
#
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=agent-config.sh
source "${SCRIPT_DIR}/agent-config.sh"
# shellcheck source=../agent/scripts/shell-utils.sh
source "${SCRIPT_DIR}/../agent/scripts/shell-utils.sh"
# shellcheck source=../agent/scripts/cli-core.sh
source "${SCRIPT_DIR}/../agent/scripts/cli-core.sh"

# =============================================================================
# 全局状态
# =============================================================================

declare -A CFG=(
  [repo_root]="${REPO_ROOT:-}"
  [target_abs]=""
  [home_abs]=""
  [store_abs]=""
  [scope]="${SDX_DEFAULT_AGENT_SCOPE}"
  [agents_opt]=""
  [dry_run]="0"
  [stamp]=""
)

# scope 展开后的开关（由 agent_scope_apply 填充）
INSTALL_RULES=0
INSTALL_SKILLS=0
INSTALL_HOOKS=0
INSTALL_SCRIPTS=0
INSTALL_KNOWLEDGE=0

declare -a ENABLED_AGENTS=()

is_agent_readme_basename() {
  local base="${1:?}"
  [[ "$base" == 'README' || "$base" == 'README.md' || "$base" == 'readme.md' ]]
}

# 同步目录树，排除各层 README / readme.md
# 须带 --delete-excluded：否则接收端仅余被 exclude 的文件（如旧目录里的 README）时，
# rsync 无法删空父目录，会报「not empty, cannot delete」（例如 reference/ 已改名为 references/）。
sync_tree_excluding_readme() {
  local src="$1" dst="$2"
  sdx_sync_dir "$src" "$dst" \
    --delete-excluded \
    --exclude 'README' --exclude 'README.md' --exclude 'readme.md'
}

copy_file_plain() {
  SDX_IO_DRY_RUN="${CFG[dry_run]:-0}"
  SDX_IO_FORCE=1
  SDX_IO_BACKUP_FN=''
  export SDX_IO_DRY_RUN SDX_IO_FORCE SDX_IO_BACKUP_FN
  sdx_io_copy_file "$1" "$2"
}

agent_store_root() {
  printf '%s\n' "${CFG[store_abs]}"
}

agent_install_root() {
  local agent="$1"
  abs_path "${CFG[target_abs]}/$(get_agent_dir "$agent")"
}

backup_existing_target_path() {
  local p="$1"
  [[ -e "$p" || -L "$p" ]] || return 0

  if [[ -L "$p" ]]; then
    local target_root existing stamp dry_run
    target_root="$(strip_trailing_slash "$(abs_path "${CFG[target_abs]}")")"
    existing="$p"
    stamp="${CFG[stamp]}"
    dry_run="${CFG[dry_run]}"

    local backup_root rel backup_target
    [[ -n "$stamp" ]] || stamp="$(date +%Y-%m-%d_%H-%M-%S)"
    backup_root="${target_root}/.docs-init/${stamp}"
    rel="$(sdx_backup_rel_under_root "$target_root" "$existing")"

    backup_target="${backup_root}/${rel}"
    if [[ -e "$backup_target" || -L "$backup_target" ]]; then
      local i=1
      while [[ -e "${backup_target}.__${i}" || -L "${backup_target}.__${i}" ]]; do (( i++ )); done
      backup_target="${backup_target}.__${i}"
    fi

    if [[ "$dry_run" == '1' ]]; then
      printf '信息: [dry-run] 将备份：%s → %s\n' "$existing" "$backup_target" >&2
      return 0
    fi

    mkdir -p "$(dirname "$backup_target")" 2>/dev/null || true
    mv "$existing" "$backup_target"
    printf '信息: 已备份：%s → %s\n' "$existing" "$backup_target" >&2
    return 0
  fi

  sdx_docs_backup_path_to_init "${CFG[target_abs]}" "$p" "${CFG[stamp]}" "${CFG[dry_run]}"
}

ensure_symlink() {
  local src="$1" dst="$2"

  if sdx_symlink_points_to "$dst" "$src"; then
    return 0
  fi

  if [[ -e "$dst" || -L "$dst" ]]; then
    backup_existing_target_path "$dst"
  fi

  if [[ "${CFG[dry_run]}" == '1' ]]; then
    sdx_log "[dry-run] 链接: $dst -> $src"
    return 0
  fi
  sdx_ensure_dir "$(dirname "$dst")"
  ln -s "$src" "$dst"
}

link_store_into_agent_root() {
  local agent="$1"
  local store agent_dir
  store="$(agent_store_root)"
  agent_dir="$(agent_install_root "$agent")"

  sdx_info ">>> 链接 ${agent}：${store} -> ${agent_dir}"
  sdx_ensure_dir "$agent_dir"

  local _nullglob_was_set=1
  sdx_nullglob_enable _nullglob_was_set
  local item base
  local src_root
  src_root="${CFG[repo_root]}/agent"

  if [[ -d "${store}" ]]; then
    for item in "${store}"/*; do
      base="${item##*/}"
      case "$base" in
        hooks|rules|scripts|skills) continue ;;
      esac
      ensure_symlink "$item" "${agent_dir}/${base}"
    done
  else
    [[ "${CFG[dry_run]}" == '1' ]] || sdx_error "未找到 agent 存储目录: ${store}"
    if (( INSTALL_HOOKS == 1 )) && [[ -f "${src_root}/hooks.json" ]]; then
      ensure_symlink "${store}/hooks.json" "${agent_dir}/hooks.json"
    fi
  fi

  local category
  for category in hooks rules scripts skills; do
    case "$category" in
      hooks)   (( INSTALL_HOOKS == 1 ))   || continue ;;
      rules)   (( INSTALL_RULES == 1 ))   || continue ;;
      scripts) (( INSTALL_SCRIPTS == 1 )) || continue ;;
      skills)  (( INSTALL_SKILLS == 1 ))  || continue ;;
    esac

    sdx_ensure_dir "${agent_dir}/${category}"

    if [[ -d "${store}/${category}" ]]; then
      for item in "${store}/${category}"/*; do
        base="${item##*/}"
        ensure_symlink "$item" "${agent_dir}/${category}/${base}"
      done
      continue
    fi

    [[ "${CFG[dry_run]}" == '1' ]] || continue
    [[ -d "${src_root}/${category}" ]] || continue
    for item in "${src_root}/${category}"/*; do
      base="${item##*/}"
      is_agent_readme_basename "$base" && continue
      ensure_symlink "${store}/${category}/${base}" "${agent_dir}/${category}/${base}"
    done
  done

  sdx_nullglob_restore _nullglob_was_set
}

# =============================================================================
# 初始化与校验
# =============================================================================

agent_install_init_repo_root() {
  if [[ -z "${CFG[repo_root]}" ]]; then
    CFG[repo_root]="$(abs_path "$SCRIPT_DIR/..")"
  fi
  local rr="${CFG[repo_root]}"
  [[ -d "$rr/agent/rules"   ]] || sdx_error "未找到 agent/rules: $rr/agent/rules"
  [[ -d "$rr/agent/skills"  ]] || sdx_error "未找到 agent/skills: $rr/agent/skills"
  [[ -d "$rr/agent/hooks"   ]] || sdx_error "未找到 agent/hooks: $rr/agent/hooks"
  [[ -d "$rr/agent/scripts" ]] || sdx_error "未找到 agent/scripts: $rr/agent/scripts"
  [[ -f "$rr/agent/scripts/docs-core.sh" ]] || sdx_error "未找到 agent/scripts/docs-core.sh: $rr/agent/scripts/docs-core.sh"
}

agent_install_apply_scope() {
  validate_agent_scope_token "${CFG[scope]}" \
    || sdx_error "无效 --scope: ${CFG[scope]}（支持 a|r|s|h|sh|k|knowledge）"
  agent_scope_apply "${CFG[scope]}" INSTALL_RULES INSTALL_SKILLS INSTALL_HOOKS INSTALL_SCRIPTS INSTALL_KNOWLEDGE \
    || sdx_error "内部错误：无法应用 scope: ${CFG[scope]}"
}

agent_install_apply_agents() {
  local ao="${CFG[agents_opt]:-}"
  [[ -n "$ao" ]] || ao="${AGENTS_OPT:-$SDX_DEFAULT_AGENTS_OPT}"
  validate_agents "$ao" \
    || sdx_error "无效 --agents: ${ao}（仅支持 cursor、claude、codex、trae、kiro）"
  read -ra ENABLED_AGENTS <<< "$(normalize_agents "$ao")"
  (( ${#ENABLED_AGENTS[@]} > 0 )) || sdx_error "未解析到任何 Agent"
}

# =============================================================================
# 安装各子树
# =============================================================================

install_agent_resource() {
  local label="$1" src_rel="$2" dst_rel="$3"
  local src_root="${CFG[repo_root]}/${src_rel}"
  local item base dst_dir

  [[ -d "$src_root" ]] || { sdx_warn "未找到 ${src_root}，跳过 ${label}"; return 0; }

  dst_dir="$(agent_store_root)/${dst_rel}"
  sdx_info ">>> 安装：${label}"
  sdx_ensure_dir "$dst_dir"
  sdx_info "  同步 ${label}：${src_root} → ${dst_dir}"

  local _nullglob_was_set=1
  sdx_nullglob_enable _nullglob_was_set
  for item in "$src_root"/*; do
    base="${item##*/}"
    is_agent_readme_basename "$base" && continue
    [[ "$label" == "scripts" && "$base" == "docs-core.sh" ]] && continue

    if [[ -d "$item" ]]; then
      sync_tree_excluding_readme "$item" "$dst_dir/$base"
    else
      copy_file_plain "$item" "$dst_dir/$base"
    fi
  done
  sdx_nullglob_restore _nullglob_was_set
}

install_agent_scripts() {
  (( INSTALL_SCRIPTS == 1 )) || return 0
  install_agent_resource "scripts" "agent/scripts" "scripts"

  # 补充 docs-core.sh
  local src_docs_ssot="${CFG[repo_root]}/agent/scripts/docs-core.sh"
  copy_file_plain "$src_docs_ssot" "$(agent_store_root)/scripts/docs-core.sh"
}

install_agent_skills() {
  (( INSTALL_SKILLS == 1 )) || return 0
  install_agent_resource "skills" "agent/skills" "skills"
}

install_agent_rules() {
  (( INSTALL_RULES == 1 )) || return 0
  install_agent_resource "rules" "agent/rules" "rules"
}

install_agent_hooks() {
  (( INSTALL_HOOKS == 1 )) || return 0
  local hooks_src="${CFG[repo_root]}/agent/hooks"
  local hooks_json="${CFG[repo_root]}/agent/hooks.json"
  local store

  [[ -d "$hooks_src" || -f "$hooks_json" ]] || { sdx_warn "未找到 agent/hooks 或 agent/hooks.json"; return 0; }

  store="$(agent_store_root)"
  sdx_info ">>> 安装：hooks"
  [[ -d "$hooks_src" ]] && sync_tree_excluding_readme "$hooks_src" "${store}/hooks"
  [[ -f "$hooks_json" ]] && copy_file_plain "$hooks_json" "${store}/hooks.json"
}

install_agent_knowledge_tree() {
  (( INSTALL_KNOWLEDGE == 1 )) || return 0
  install_agent_resource "knowledge" "agent/knowledge" "knowledge"
  install_agent_resource "references" "agent/references" "references"
}

agent_install_install() {
  install_agent_scripts
  install_agent_rules
  install_agent_skills
  install_agent_hooks
  install_agent_knowledge_tree

  local agent
  for agent in "${ENABLED_AGENTS[@]}"; do
    link_store_into_agent_root "$agent"
  done
}

# 计算 agent-install 写回 .docsconfig 所需 AGENT_*
# 用法：install_agent_path <nameref_agent_root_out> <nameref_agent_dirs_out>
install_agent_path() {
  local -n _ar_out="${1:?}"
  local -n _ads_out="${2:?}"
  _ar_out="$(strip_trailing_slash "${CFG[target_abs]}")"
  _ads_out="$(agent_dirs_space_separated_for "${ENABLED_AGENTS[@]}")"
}

# =============================================================================
# install config：target ≠ $HOME 时更新 AGENT_ROOT / AGENT_DIRS
# =============================================================================

agent_install_update_docsconfig() {
  local t h
  t="$(strip_trailing_slash "${CFG[target_abs]}")"
  h="$(strip_trailing_slash "${CFG[home_abs]}")"
  [[ "$t" != "$h" ]] || return 0

  local cfg="$t/.docsconfig"
  [[ -f "$cfg" ]] \
    || sdx_error "未找到 ${cfg}。请先在该工程执行 docs-install（或 docs-install --scope=config <目标工程文档目录>）生成 .docsconfig。"

  local doc_root repo_root doc_dir _ar_old _ads_old kt
  docsconfig_read_into "$cfg" doc_root repo_root doc_dir _ar_old _ads_old kt \
    || sdx_error "无法解析: ${cfg}"

  [[ -n "$doc_root" && -n "$repo_root" && -n "$doc_dir" ]] \
    || sdx_error ".docsconfig 缺少 DOC_ROOT/REPO_ROOT/DOC_DIR，请重新执行 docs-install。"

  local ar ads
  install_agent_path ar ads

  sdx_info ">>> 更新 .docsconfig 中的 AGENT_ROOT / AGENT_DIRS（按本次参数重算）: ${cfg}"
  docsconfig_write "$t" "$doc_root" "$doc_dir" "${CFG[dry_run]}" "$ar" "$ads" "${kt:-}"
}

# =============================================================================
# CLI
# =============================================================================

agent_install_usage() {
  cat >&2 <<'EOF'
用法
  agent-install.sh [选项]

说明
  将本仓库 agent/ 树安装到 $HOME/.agents/（单份实体存储），并按 --agents
  在 ${TARGET}/.{.cursor|.trae|.claude|.kiro|.codex}/ 下建立软链（按条目链接，包含 $HOME/.agents/ 根文件与
  hooks/rules/scripts/skills/knowledge/references 等子目录下的各文件/目录）。
  scripts 阶段会从本仓库复制 agent/scripts/docs-core.sh 到 $HOME/.agents/scripts/docs-core.sh。
  不安装 README。
  当 --target 不是 $HOME 时，更新 <target>/.docsconfig 的 AGENT_ROOT 与 AGENT_DIRS（与当前 --agents 一致）；
  若该文件不存在，请先对目标工程执行 docs-install。

选项
  --scope=SCOPE   a=全部 | r=rules | s=skills | h=hooks | sh=scripts | k|knowledge=knowledge+references  [默认: a]
  --target PATH   安装根父目录，其下仅为选中的 agent 创建对应目录  [默认: $HOME；仍兼容 --target=PATH]
  --agents=LIST   cursor | trae | claude | kiro | codex | all；逗号或空格分隔多选  [默认: cursor]
  --dry-run       仅打印将执行的操作
  -h, --help      显示此帮助

环境变量
  REPO_ROOT       本仓库（中央库）根目录（默认：本脚本所在仓库根）
  AGENTS_OPT      未传 --agents 时作为默认值（否则以命令行 --agents 为准）

示例
  ./scripts/agent-install.sh
  ./scripts/agent-install.sh --agents=cursor,claude
  ./scripts/agent-install.sh --scope=sh --dry-run
  ./scripts/agent-install.sh --scope=k --dry-run
  ./scripts/agent-install.sh --target ~/workspace/my-repo --agents=all
EOF
}

agent_install_parse_args() {
  while (( $# > 0 )); do
    case "$1" in
      --scope=*)
        CFG[scope]="${1#*=}"
        shift
        ;;
      --scope)
        shift
        sdx_cli_require_value "--scope" "${1:-}"
        CFG[scope]="$1"
        shift
        ;;
      --target=*)
        CFG[target_abs]="${1#*=}"
        shift
        ;;
      --target)
        shift
        sdx_cli_require_value "--target" "${1:-}"
        CFG[target_abs]="$1"
        shift
        ;;
      --agents=*)
        CFG[agents_opt]="${1#*=}"
        shift
        ;;
      --agents)
        shift
        local -a parts=()
        while (( $# > 0 )); do
          case "$1" in -*) break ;; *) parts+=("$1"); shift ;; esac
        done
        (( ${#parts[@]} > 0 )) || sdx_error "缺少 --agents 值（如 cursor,trae 或 cursor trae）"
        CFG[agents_opt]="$(IFS=','; printf '%s' "${parts[*]}")"
        ;;
      --dry-run)
        CFG[dry_run]=1
        shift
        ;;
      -h|--help)
        agent_install_usage
        exit 0
        ;;
      *)
        sdx_cli_unknown_arg "$1" "支持 --scope / --target / --agents / --dry-run"
        ;;
    esac
  done
}

agent_install_run() {
  agent_install_init_repo_root
  [[ -n "${HOME:-}" ]] || sdx_error "需要 HOME 环境变量"
  CFG[home_abs]="$(abs_path "$HOME")"
  CFG[store_abs]="$(strip_trailing_slash "$(abs_path "${CFG[home_abs]}/.agents")")"
  CFG[stamp]="$(date +%Y-%m-%d_%H-%M-%S)"

  if [[ -z "${CFG[target_abs]:-}" ]]; then
    CFG[target_abs]="${CFG[home_abs]}"
  else
    CFG[target_abs]="$(strip_trailing_slash "$(abs_path "${CFG[target_abs]}")")"
  fi

  sdx_ensure_dir "$(agent_store_root)"

  agent_install_apply_scope
  agent_install_apply_agents

  (( INSTALL_HOOKS == 1 )) && sdx_ensure_dir "$(agent_store_root)/hooks"
  (( INSTALL_RULES == 1 )) && sdx_ensure_dir "$(agent_store_root)/rules"
  (( INSTALL_SCRIPTS == 1 )) && sdx_ensure_dir "$(agent_store_root)/scripts"
  (( INSTALL_SKILLS == 1 )) && sdx_ensure_dir "$(agent_store_root)/skills"
  if (( INSTALL_KNOWLEDGE == 1 )); then
    sdx_ensure_dir "$(agent_store_root)/knowledge"
    sdx_ensure_dir "$(agent_store_root)/references"
  fi

  agent_install_install
  agent_install_update_docsconfig

  sdx_info "完成：agent-install"
}

agent_install_main() {
  agent_install_parse_args "$@"
  agent_install_run
}

agent_install_main "$@"
