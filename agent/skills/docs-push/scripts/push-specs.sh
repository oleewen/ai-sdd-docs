#!/usr/bin/env bash
# push-specs.sh：legacy → {doc_dir}/specs/；spec-asd → requirements/…/MVP-Phase-*/specs/（归位或 requirements/ 镜像）
# 子命令 copy|git → references/parameters.md
set -euo pipefail

readonly _INVOCATION_PWD="$(pwd -P)"
readonly _PS_SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

_ps_bootstrap_error() {
  printf '%s\n' "$*" >&2
  exit 1
}

_ps_source_docs_core() {
  local dc
  if [[ -n "${DOCS_CORE_SH:-}" ]]; then
    [[ -f "$DOCS_CORE_SH" ]] || _ps_bootstrap_error "DOCS_CORE_SH 已设置但文件不存在: ${DOCS_CORE_SH}"
    # shellcheck source=/dev/null
    source "$DOCS_CORE_SH"
    return 0
  fi
  dc="${_PS_SCRIPT_DIR}/../../../scripts/docs-core.sh"
  if [[ -f "$dc" ]]; then
    # shellcheck source=/dev/null
    source "$dc"
    return 0
  fi
  for dc in \
    "${HOME}/.agents/scripts/docs-core.sh" \
    "${HOME}/.cursor/scripts/docs-core.sh" \
    "${HOME}/.trae/scripts/docs-core.sh" \
    "${HOME}/.claude/scripts/docs-core.sh" \
    "${HOME}/.kiro/scripts/docs-core.sh" \
    "${HOME}/.codex/scripts/docs-core.sh"; do
    if [[ -f "$dc" ]]; then
      # shellcheck source=/dev/null
      source "$dc"
      return 0
    fi
  done
  return 1
}

_ps_source_docs_core || _ps_bootstrap_error \
  "push-specs.sh: 无法找到 docs-core.sh。" \
  "可设置 DOCS_CORE_SH，或确保已 agent-install（~/.agents/scripts/docs-core.sh），或在中央库内执行，或 export AIK_ROOT 指向含 agent/scripts/docs-core.sh 的仓库根。"

usage() {
  sed 's/^    //' <<'EOF'
    用法:
      push-specs.sh copy --specs-dir DIR --links FILE [--mode path|repo] [--branch NAME]
                         [--dry-run] [--strict] [--allow-dirty]
      push-specs.sh git  --specs-dir DIR --links FILE [--mode path|repo] [--branch NAME]
                         --git-op none|stage|commit|push [--message TEXT] [--remote NAME]
                         [--dry-run] [--strict] [--allow-dirty]

    必选:
      --specs-dir   源目录根（legacy 仅扫描顶层 *.md；spec-asd-* 递归 find）
      --links       knowledge-links.yaml（相对仓库根或绝对路径）
    repo 模式:
      --mode repo   且 copy/git 均须在目标 path 上切换分支时提供 --branch
    git 子命令:
      --git-op      none | stage | commit | push
      commit/push  须配合 --message

    相对 --links：中央仓库根解析见 agent/skills/docs-push/references/parameters.md
EOF
}

# 相对 --links 的仓库根：AIK_ROOT → 上溯含 links 文件 → 上溯 agent/scripts 标记（见 docs-core sdx_find_upward_with_file）
_aik_resolve_root_for_links() {
  local rel="${1:?}" root
  if [[ -n "${AIK_ROOT:-}" ]]; then
    root="$(cd -P "${AIK_ROOT}" 2>/dev/null && pwd -P)" || \
      sdx_error "AIK_ROOT 无法进入: ${AIK_ROOT}"
    [[ -f "$root/$rel" ]] || \
      sdx_error "AIK_ROOT 下不存在 ${rel}（当前 AIK_ROOT=$root）"
    printf '%s\n' "$root"
    return 0
  fi
  if root="$(sdx_find_upward_with_file "$rel" "${_INVOCATION_PWD}")"; then
    printf '%s\n' "$root"
    return 0
  fi
  sdx_find_upward_with_file "agent/scripts/docs-core.sh" "${_INVOCATION_PWD}" "${_PS_SCRIPT_DIR}"
}

CMD="${1:-}"
[[ "$CMD" == copy || "$CMD" == git ]] || {
  usage >&2
  exit 2
}
shift

SPECS_DIR=''
LINKS_FILE=''
MODE='path'
BRANCH=''
DRY_RUN=0
STRICT=0
ALLOW_DIRTY=0
GIT_OP=''
MESSAGE=''
REMOTE='origin'

while [[ $# -gt 0 ]]; do
  case "$1" in
    --specs-dir)
      SPECS_DIR="${2:?}"; shift 2 ;;
    --links)
      LINKS_FILE="${2:?}"; shift 2 ;;
    --mode)
      MODE="${2:?}"; shift 2 ;;
    --branch)
      BRANCH="${2:?}"; shift 2 ;;
    --dry-run)
      DRY_RUN=1; shift ;;
    --strict)
      STRICT=1; shift ;;
    --allow-dirty)
      ALLOW_DIRTY=1; shift ;;
    --git-op)
      GIT_OP="${2:?}"; shift 2 ;;
    --message)
      MESSAGE="${2:?}"; shift 2 ;;
    --remote)
      REMOTE="${2:?}"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      sdx_error "未知参数: $1" ;;
  esac
done

[[ -n "$SPECS_DIR" ]] || sdx_error "缺少 --specs-dir"
[[ -n "$LINKS_FILE" ]] || sdx_error "缺少 --links"
[[ -d "$SPECS_DIR" ]] || sdx_error "specs 目录不存在或不是目录: $SPECS_DIR"

if [[ "$LINKS_FILE" != /* ]]; then
  [[ "$LINKS_FILE" != *..* ]] || sdx_error "相对 --links 不得包含 ..: $LINKS_FILE"
  _AIK_ROOT="$(_aik_resolve_root_for_links "$LINKS_FILE")" || sdx_error \
    "无法解析相对 --links 的仓库根（未找到 ${LINKS_FILE} 于当前目录任一上级，且未找到 agent/scripts/docs-core.sh）。请 cd 到中央库根或其子目录，或 export AIK_ROOT=含该文件的仓库根，或改用绝对路径 --links。"
  LINKS_FILE="${_AIK_ROOT}/${LINKS_FILE}"
fi
[[ -f "$LINKS_FILE" ]] || sdx_error "knowledge-links 文件不存在: $LINKS_FILE"

# 物理路径：避免 macOS /var ↔ /private/var 等与 find -print 前缀不一致导致相对路径计算失败
SPECS_DIR="$(cd -P "$SPECS_DIR" && pwd)"

[[ "$MODE" == path || "$MODE" == repo ]] || sdx_error "--mode 须为 path 或 repo: $MODE"
if [[ "$MODE" == repo ]]; then
  [[ -n "$BRANCH" ]] || sdx_error "repo 模式必须提供 --branch"
fi

if [[ "$CMD" == git ]]; then
  [[ -n "$GIT_OP" ]] || sdx_error "git 子命令必须提供 --git-op"
  [[ "$GIT_OP" == none || "$GIT_OP" == stage || "$GIT_OP" == commit || "$GIT_OP" == push ]] || \
    sdx_error "--git-op 须为 none|stage|commit|push: $GIT_OP"
  if [[ "$GIT_OP" == commit || "$GIT_OP" == push ]]; then
    [[ -n "$MESSAGE" ]] || sdx_error "git-op=$GIT_OP 时必须提供 --message"
  fi
fi

# shellcheck disable=SC2034
paths=() repos=() doc_dirs=() app_names=() app_labels=()
knowledge_links_load_into_arrays "$LINKS_FILE" paths repos doc_dirs app_names app_labels

find_link_index_for_app() {
  local want="${1:?}" i
  for ((i = 0; i < ${#app_names[@]}; i++)); do
    if [[ "${app_names[i]:-}" == "$want" ]]; then
      printf '%s' "$i"
      return 0
    fi
  done
  return 1
}

# 相对路径段含独立 ".." 则返回 0（坏）
_ps_rel_has_dot_dot() {
  local rel="${1:?}"
  [[ "$rel" =~ (^|/)\.\.(/|$) ]]
}

# 规范源绝对路径，并返回相对 SPECS_DIR 的路径（不含前导 /）
_ps_rel_from_specs_root() {
  local abs="${1:?}" root="${2:?}"
  local pfx="${root}/"
  [[ "$abs" == "$pfx"* ]] || {
    sdx_error "内部错误: 源文件不在 --specs-dir 下: $abs"
    return 1
  }
  printf '%s' "${abs#"$pfx"}"
}

# 解析 spec-asd-{IDEA}-{PHASE}-{app}.md（自右向左）；失败返回 1。输出三行：IDEA / PHASE / APP
_ps_parse_spec_asd_basename() {
  local base="${1:?}" body rest app phase idea
  [[ "$base" == spec-asd-*.md ]] || return 1
  body="${base#spec-asd-}"
  body="${body%.md}"
  [[ -n "$body" ]] || return 1
  app="${body##*-}"
  [[ "$app" =~ ^[a-zA-Z0-9_.-]+$ ]] || return 1
  rest="${body%"${app}"}"
  [[ "$rest" == *-* ]] || return 1
  rest="${rest%-}"
  [[ -n "$rest" ]] || return 1
  phase="${rest##*-}"
  [[ "$phase" =~ ^[0-9]+$ ]] || return 1
  idea="${rest%"${phase}"}"
  idea="${idea%-}"
  [[ -n "$idea" ]] || return 1
  while [[ "$idea" == *- ]]; do
    idea="${idea%-}"
  done
  [[ -n "$idea" ]] || return 1
  [[ "$idea" =~ ^[a-zA-Z0-9_.-]+$ ]] || return 1
  printf '%s\n%s\n%s\n' "$idea" "$phase" "$app"
}

# dirname(relative_under_doc_root) 须落在 requirements/REQUIREMENT-*/MVP-Phase-*/specs[/…] 下
_ps_spec_asd_mirror_dd_ok() {
  local rt="${1:?}"
  local ddir
  ddir="$(dirname "$rt")"
  [[ "$ddir" =~ ^requirements/REQUIREMENT-[^/]+/MVP-Phase-[^/]+/specs(/.*)?$ ]]
}

# 写入计划文件：每行 src_abs<TAB>dest_abs<TAB>repo_root_expanded
# 严格模式：任一条目解析失败则不写任何行并返回 1
write_validated_plan() {
  local out="${1:?}"
  local spec_re='^spec-([0-9]{6})-([0-9]+)-([a-zA-Z0-9_.-]+)\.md$'
  local f base idx doc_dir exp_root dest app rel doc_base parsed_idea parsed_phase parsed_app parsed_blob
  local had_skip=0
  : >"$out"
  shopt -s nullglob
  for f in "$SPECS_DIR"/*.md; do
    [[ -f "$f" ]] || continue
    base="$(basename "$f")"
    [[ "$base" == spec-asd-*.md ]] && continue
    if [[ ! "$base" =~ $spec_re ]]; then
      sdx_warn "[skip] 文件名不符合 spec-{yyMMdd}-{n}-{app_name}.md: $base"
      had_skip=1
      continue
    fi
    app="${BASH_REMATCH[3]}"
    if ! idx="$(find_link_index_for_app "$app")"; then
      sdx_warn "[skip] 未在 knowledge-links 中找到 app_name=$app: $base"
      had_skip=1
      continue
    fi
    doc_dir="${doc_dirs[idx]:-application}"
    exp_root="$(knowledge_link_expand_stored_path "${paths[idx]}")"
    exp_root="$(cd "$exp_root" 2>/dev/null && pwd)" || sdx_error "无法进入 path 目录: ${paths[idx]} → $exp_root"
    dest="${exp_root}/${doc_dir}/specs/${base}"
    printf '%s\t%s\t%s\n' "$f" "$dest" "$exp_root" >>"$out"
  done
  shopt -u nullglob

  local asd_list abs_asd
  asd_list="$(mktemp)"
  find "$SPECS_DIR" -type f -name 'spec-asd-*.md' ! -path '*/.*' 2>/dev/null \
    | LC_ALL=C sort >"$asd_list" || true
  while IFS= read -r f || [[ -n "$f" ]]; do
    [[ -z "$f" ]] && continue
    abs_asd="$(cd -P "$(dirname "$f")" && pwd)/$(basename "$f")"
    rel="$(_ps_rel_from_specs_root "$abs_asd" "$SPECS_DIR")"
    if _ps_rel_has_dot_dot "$rel"; then
      sdx_warn "[skip] 相对路径非法（含 ..）: $rel （源 $abs_asd）"
      had_skip=1
      continue
    fi
    base="$(basename "$abs_asd")"
    if ! parsed_blob="$(_ps_parse_spec_asd_basename "$base")"; then
      sdx_warn "[skip] spec-asd 文件名无法解析（期望 spec-asd-{IDEA-ID}-{PHASE}-{app-name}.md）: $base"
      had_skip=1
      continue
    fi
    parsed_idea='' parsed_phase='' parsed_app=''
    {
      IFS= read -r parsed_idea || true
      IFS= read -r parsed_phase || true
      IFS= read -r parsed_app || true
    } <<< "$parsed_blob"
    if [[ -z "${parsed_idea:-}" || -z "${parsed_phase:-}" || -z "${parsed_app:-}" ]]; then
      sdx_warn "[skip] spec-asd 解析字段不完整: $base"
      had_skip=1
      continue
    fi

    if ! idx="$(find_link_index_for_app "$parsed_app")"; then
      sdx_warn "[skip] 未在 knowledge-links 中找到 app_name=$parsed_app: $base"
      had_skip=1
      continue
    fi
    doc_dir="${doc_dirs[idx]:-application}"
    exp_root="$(knowledge_link_expand_stored_path "${paths[idx]}")"
    exp_root="$(cd "$exp_root" 2>/dev/null && pwd)" || sdx_error "无法进入 path 目录: ${paths[idx]} → $exp_root"
    doc_base="${exp_root}/${doc_dir}"

    if [[ "$rel" == requirements/* ]]; then
      dest="${doc_base}/${rel}"
      dest_rel="${rel}"
      if ! _ps_spec_asd_mirror_dd_ok "$dest_rel"; then
        sdx_warn "[skip] spec-asd 镜像目标须位于 requirements/REQUIREMENT-*/MVP-Phase-*/specs/ 下: $dest"
        had_skip=1
        continue
      fi
    else
      dest="${doc_base}/requirements/REQUIREMENT-${parsed_idea}/MVP-Phase-${parsed_phase}/specs/${base}"
    fi

    printf '%s\t%s\t%s\n' "$abs_asd" "$dest" "$exp_root" >>"$out"
  done <"$asd_list"
  rm -f "$asd_list"

  if [[ "$STRICT" -eq 1 && "$had_skip" -ne 0 ]]; then
    : >"$out"
    return 1
  fi
  return 0
}

# 检查工作区：除 planned_rel 中路径外不得有其它变更
check_worktree_clean_for_plan() {
  local root="${1:?}"
  shift
  local -a planned=("$@")
  local line xy p path rest
  [[ "$ALLOW_DIRTY" -eq 1 ]] && return 0
  git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "${line//[[:space:]]/}" ]] && continue
    xy="${line:0:2}"
    rest="${line:3}"
    local -a candidates=()
    if [[ "$rest" == *" -> "* ]]; then
      candidates+=("${rest%% -> *}")
      candidates+=("${rest##* -> }")
    else
      candidates+=("$rest")
    fi
    local p ok q
    for p in "${candidates[@]}"; do
      [[ -z "$p" ]] && continue
      ok=0
      for q in "${planned[@]}"; do
        if [[ "$p" == "$q" ]]; then
          ok=1
          break
        fi
      done
      if [[ "$ok" -eq 0 ]]; then
        sdx_error "Git 工作区存在与本次推送无关的变更（path=$root 文件: $p）。请先提交或清理，或使用 --allow-dirty。"
      fi
    done
  done < <(git -C "$root" status --porcelain)
}

rel_under_root() {
  local dest="${1:?}" root="${2:?}"
  if [[ "$dest" != "$root"/* ]]; then
    sdx_error "目标路径不在仓库根下: dest=$dest root=$root"
  fi
  printf '%s' "${dest#"${root}"/}"
}

run_copy() {
  local plan_line src dest root
  local -a roots_order=()
  local -A root_done=()

  local plan_file
  plan_file="$(mktemp)"
  if ! write_validated_plan "$plan_file"; then
    rm -f "$plan_file"
    sdx_error "strict 模式：存在无法路由的 spec，已中止（未写任何目标文件）"
  fi
  if [[ ! -s "$plan_file" ]]; then
    rm -f "$plan_file"
    sdx_error "没有可复制的 spec 文件（检查命名与 app_name 登记）"
  fi

  # repo 模式：按 root 分组，首次遇到 root 时 dirty + checkout
  while IFS= read -r plan_line || [[ -n "$plan_line" ]]; do
    [[ -z "$plan_line" ]] && continue
    IFS=$'\t' read -r src dest root <<<"$plan_line"

    if [[ "$MODE" == repo ]]; then
      if [[ -z "${root_done[$root]:-}" ]]; then
        root_done["$root"]=1
        roots_order+=("$root")
      fi
    fi
  done <"$plan_file"

  if [[ "$MODE" == repo ]]; then
    local r
    for r in "${roots_order[@]}"; do
      local -a planned_for_r=()
      while IFS= read -r plan_line || [[ -n "$plan_line" ]]; do
        [[ -z "$plan_line" ]] && continue
        IFS=$'\t' read -r src dest root <<<"$plan_line"
        [[ "$root" != "$r" ]] && continue
        planned_for_r+=("$(rel_under_root "$dest" "$root")")
      done <"$plan_file"
      if [[ "$DRY_RUN" -eq 1 ]]; then
        printf '[dry-run] git -C %q checkout -B %q\n' "$r" "$BRANCH" >&2
      else
        check_worktree_clean_for_plan "$r" "${planned_for_r[@]}"
        git -C "$r" rev-parse --is-inside-work-tree >/dev/null 2>&1 || \
          sdx_error "repo 模式要求 path 为 Git 工作区: $r"
        git -C "$r" checkout -B "$BRANCH"
      fi
    done
  fi

  while IFS= read -r plan_line || [[ -n "$plan_line" ]]; do
    [[ -z "$plan_line" ]] && continue
    IFS=$'\t' read -r src dest root <<<"$plan_line"
    if [[ "$DRY_RUN" -eq 1 ]]; then
      printf '[dry-run] install %q %q\n' "$src" "$dest" >&2
      continue
    fi
    mkdir -p "$(dirname "$dest")"
    install -m 0644 "$src" "$dest"
    printf '已复制: %s -> %s\n' "$src" "$dest"
  done <"$plan_file"

  rm -f "$plan_file"
}

# 按仓库根聚合 rel 路径，对每个根执行一次 add / commit / push
run_git() {
  local plan_file plan_line src dest root r
  local -A root_done=()
  local -a roots_order=()

  plan_file="$(mktemp)"
  if ! write_validated_plan "$plan_file"; then
    rm -f "$plan_file"
    sdx_error "strict 模式：存在无法路由的 spec，已中止"
  fi
  [[ -s "$plan_file" ]] || {
    rm -f "$plan_file"
    sdx_error "没有可处理的 spec 文件"
  }

  while IFS= read -r plan_line || [[ -n "$plan_line" ]]; do
    [[ -z "$plan_line" ]] && continue
    IFS=$'\t' read -r src dest root <<<"$plan_line"
    if [[ "$MODE" == repo ]]; then
      if [[ -z "${root_done[$root]:-}" ]]; then
        root_done["$root"]=1
        roots_order+=("$root")
      fi
    fi
  done <"$plan_file"

  if [[ "$MODE" == repo ]]; then
    for r in "${roots_order[@]}"; do
      local -a planned_for_r=()
      while IFS= read -r plan_line || [[ -n "$plan_line" ]]; do
        [[ -z "$plan_line" ]] && continue
        IFS=$'\t' read -r src dest root <<<"$plan_line"
        [[ "$root" != "$r" ]] && continue
        planned_for_r+=("$(rel_under_root "$dest" "$r")")
      done <"$plan_file"
      if [[ "$DRY_RUN" -eq 1 ]]; then
        printf '[dry-run] git -C %q checkout -B %q\n' "$r" "$BRANCH" >&2
      else
        check_worktree_clean_for_plan "$r" "${planned_for_r[@]}"
        git -C "$r" rev-parse --is-inside-work-tree >/dev/null 2>&1 || \
          sdx_error "repo 模式要求 path 为 Git 工作区: $r"
        git -C "$r" checkout -B "$BRANCH"
      fi
    done
  fi

  # 聚合: root -> rel 列表
  local -a uniq_roots=()
  while IFS= read -r plan_line || [[ -n "$plan_line" ]]; do
    [[ -z "$plan_line" ]] && continue
    IFS=$'\t' read -r src dest root <<<"$plan_line"
    if ! git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      sdx_warn "[skip] 非 Git 目录，跳过 git 操作: $root"
      continue
    fi
    local found=0 u
    for u in "${uniq_roots[@]}"; do
      if [[ "$u" == "$root" ]]; then found=1; break; fi
    done
    [[ "$found" -eq 0 ]] && uniq_roots+=("$root")
  done <"$plan_file"

  for root in "${uniq_roots[@]}"; do
    local -a rels=()
    while IFS= read -r plan_line || [[ -n "$plan_line" ]]; do
      [[ -z "$plan_line" ]] && continue
      IFS=$'\t' read -r src dest r <<<"$plan_line"
      [[ "$r" != "$root" ]] && continue
      rels+=("$(rel_under_root "$dest" "$root")")
    done <"$plan_file"

    case "$GIT_OP" in
      none)
        if [[ "$DRY_RUN" -eq 1 ]]; then
          printf '[dry-run] git -C %q status -sb\n' "$root" >&2
        else
          git -C "$root" status -sb || true
        fi
        ;;
      stage)
        if [[ "$DRY_RUN" -eq 1 ]]; then
          printf '[dry-run] git -C %q add --' "$root" >&2
          printf ' %q' "${rels[@]}" >&2
          printf '\n' >&2
        else
          [[ "${#rels[@]}" -gt 0 ]] && git -C "$root" add -- "${rels[@]}"
        fi
        ;;
      commit)
        if [[ "$DRY_RUN" -eq 1 ]]; then
          printf '[dry-run] git -C %q add --' "$root" >&2
          printf ' %q' "${rels[@]}" >&2
          printf ' && git -C %q commit -m %q\n' "$root" "$MESSAGE" >&2
        else
          [[ "${#rels[@]}" -gt 0 ]] && git -C "$root" add -- "${rels[@]}"
          if git -C "$root" diff-index --cached --quiet HEAD -- 2>/dev/null; then
            sdx_warn "无暂存变更，跳过 commit: $root"
          else
            git -C "$root" commit -m "$MESSAGE"
          fi
        fi
        ;;
      push)
        if [[ "$DRY_RUN" -eq 1 ]]; then
          printf '[dry-run] git -C %q add --' "$root" >&2
          printf ' %q' "${rels[@]}" >&2
          printf ' && git -C %q commit -m %q && git -C %q push %q HEAD\n' \
            "$root" "$MESSAGE" "$root" "$REMOTE" >&2
        else
          [[ "${#rels[@]}" -gt 0 ]] && git -C "$root" add -- "${rels[@]}"
          if git -C "$root" diff-index --cached --quiet HEAD -- 2>/dev/null; then
            sdx_warn "无暂存变更，跳过 commit/push: $root"
          else
            git -C "$root" commit -m "$MESSAGE"
            git -C "$root" push "$REMOTE" HEAD
          fi
        fi
        ;;
    esac
  done

  rm -f "$plan_file"
}

case "$CMD" in
  copy) run_copy ;;
  git) run_git ;;
esac
