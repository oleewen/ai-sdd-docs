#!/usr/bin/env bash
# docs-link.sh — 在源知识库登记 / 注销目标知识库（repository + path + doc_dir + app_name + app_label）
# application 建联时 app_name：--app-name > 登记文件已有 > Git 仓库根目录名推断
# app_label：新登记或条目中尚无 app_label 时默认等于 app_name；重复 link 且已有 app_label 则保留不覆盖
# 同一 target 重复 link：合并更新同一条记录，不追加重复行
# 用法: ./scripts/docs-link.sh --link|--unlink --target <目标仓库根> [--app-name=名] [--dry-run]
# 须在源 Git 仓库内执行；link 需校验源、目标 .docsconfig 与 KNOWLEDGE_TYPE；
# unlink 支持目标失联场景（按登记 identity 注销）；system 源注销 application 建联时先将
# DOC_ROOT 下 application-<APPNAME>/ 备份至 REPO_ROOT/.docs-init/<时间戳>/（与 docs-install 一致）再移除。
# 登记值：repository 存 Git remote URL（有 remote 时）；path 存本机路径（在 $HOME 下为 ~/ 前缀的
#       路径，家目录本身写 ~/；否则为规范化绝对路径）。兼容旧数据：无 ~ 的 $HOME 相对片段仍可读。
#       path 不得为 URL 形态（须写在 repository）。不兼容旧版仅 path=URL 的 YAML。
# link 同时在目标 {DOC_ROOT}/knowledge-parent.yaml 写入源仓 identity（1:1）；unlink 将跨层 HTTP 改为纯 ID。
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./link-config.sh
source "${SCRIPT_DIR}/link-config.sh"

docs_link_okf_parent_py() {
  local c
  for c in \
    "${SCRIPT_DIR}/../agent/skills/docs-okf/scripts/okf_parent.py" \
    "${_sar:-}/skills/docs-okf/scripts/okf_parent.py"
  do
    [[ -n "$c" && -f "$c" ]] && { printf '%s\n' "$c"; return 0; }
  done
  sdx_error "未找到 okf_parent.py（跨层 parent 写入）"
}

docs_link_run_okf_parent() {
  local py
  py="$(docs_link_okf_parent_py)"
  if [[ "$DRY" == '1' ]]; then
    python3 "$py" --dry-run "$@"
  else
    python3 "$py" "$@"
  fi
}

docs_link_abs_under_repo() {
  local repo="${1:?}" doc="${2:?}"
  local repo_abs doc_abs
  repo_abs="$(strip_trailing_slash "$(abs_path "$repo")")"
  if [[ "$doc" == /* ]]; then
    doc_abs="$(strip_trailing_slash "$(abs_path "$doc")")"
    case "$doc_abs" in
      "$repo_abs"|"$repo_abs"/*) printf '%s\n' "$doc_abs" ;;
      *)
        printf '%s\n' "$repo_abs/$(basename "$doc_abs")"
        ;;
    esac
  else
    strip_trailing_slash "$(abs_path "$repo_abs/$doc")"
  fi
}

docs_link_write_child_parent() {
  local src_repo src_path src_dd tdoc_abs sdoc_abs
  src_repo="$(knowledge_link_git_remote_url_prefer_origin "$SRC_ROOT" || true)"
  src_path="$(knowledge_link_stored_path_from_absolute "$SRC_ROOT")"
  sdoc_abs="$(docs_link_abs_under_repo "$SRC_ROOT" "$_sdoc")"
  src_dd="$(docsconfig_doc_dir_from_roots "$SRC_ROOT" "$sdoc_abs")" \
    || sdx_error "无法计算源 DOC_DIR（DOC_ROOT 须位于 REPO_ROOT 下）"
  tdoc_abs="$(docs_link_abs_under_repo "$TGT_ROOT" "$_tdoc")"
  docs_link_run_okf_parent write \
    --doc-root "$tdoc_abs" \
    --knowledge-type "$_skt" \
    --repository "${src_repo}" \
    --path "$src_path" \
    --doc-dir "$src_dd" \
    --ref main
}

docs_link_unlink_child_parent() {
  local tgt_cfg tdoc trepo tdd tar tads tkt tdoc_abs
  [[ -d "${TARGET_KEY:-}" ]] || return 0
  tgt_cfg="$TARGET_KEY/.docsconfig"
  [[ -f "$tgt_cfg" ]] || return 0
  tdoc=''; trepo=''; tdd=''; tar=''; tads=''; tkt=''
  docsconfig_read_into "$tgt_cfg" tdoc trepo tdd tar tads tkt || return 0
  [[ -n "$tdoc" ]] || return 0
  tdoc_abs="$(docs_link_abs_under_repo "$TARGET_KEY" "$tdoc")"
  docs_link_run_okf_parent unlink --doc-root "$tdoc_abs"
}

# =============================================================================
# knowledge-links.yaml
# =============================================================================

# YAML 双引号字段内转义（写 knowledge-links 用）
_knowledge_link_yaml_escape_dq() {
  printf '%s' "${1//\"/\\\"}"
}

# DOC_ROOT 绝对路径并去尾斜杠（槽位路径拼接用）
_knowledge_link_doc_root_abs_ns() {
  strip_trailing_slash "$(abs_path "${1:?}")"
}

# 将绝对仓库根路径转为写入 knowledge-links 的 path（SSOT：docsconfig_format_root_for_write）
knowledge_link_stored_path_from_absolute() {
  docsconfig_format_root_for_write "${1:?}"
}

# 覆盖写出 knowledge-links.yaml（repository、path、doc_dir、app_name、app_label 数组下标对齐）
knowledge_links_write_quads() {
  local f="${1:?}"
  local -n _repos="${2:?}"
  local -n _paths="${3:?}"
  local -n _dirs="${4:?}"
  local -n _apps="${5:?}"
  local -n _labels="${6:?}"
  local d i n lab
  d="$(dirname "$f")"
  n="${#_paths[@]}"
  [[ "$DRY" == '1' ]] && { printf '[dry-run] 将写入 %s（%d 条 links）\n' "$f" "$n" >&2; return 0; }
  mkdir -p "$d"
  umask 022
  {
    printf '%s\n' '# 知识库建联清单（可由 docs-link.sh 维护）'
    printf '%s\n' 'links:'
    for ((i = 0; i < n; i++)); do
      [[ -n "${_repos[i]:-}" ]] || sdx_error "knowledge-links.yaml 条目缺少 repository（必填）: $f"
      printf '  - repository: "%s"\n' "$(_knowledge_link_yaml_escape_dq "${_repos[i]}")"
      printf '    path: "%s"\n' "$(_knowledge_link_yaml_escape_dq "${_paths[i]}")"
      if [[ -n "${_dirs[i]:-}" ]]; then
        printf '    doc_dir: "%s"\n' "$(_knowledge_link_yaml_escape_dq "${_dirs[i]}")"
      fi
      if [[ "${_dirs[i]:-}" == 'system' ]]; then
        [[ -n "${_apps[i]:-}" ]] || sdx_error "knowledge-links.yaml(system) 条目缺少 sys_name（必填）: $f"
        [[ -n "${_labels[i]:-}" ]] || sdx_error "knowledge-links.yaml(system) 条目缺少 sys_label（必填）: $f"
        printf '    sys_name: "%s"\n' "$(_knowledge_link_yaml_escape_dq "${_apps[i]}")"
        printf '    sys_label: "%s"\n' "$(_knowledge_link_yaml_escape_dq "${_labels[i]}")"
      else
        [[ -n "${_apps[i]:-}" ]] || sdx_error "knowledge-links.yaml(application) 条目缺少 app_name（必填）: $f"
        lab="${_labels[i]:-${_apps[i]}}"
        [[ -n "$lab" ]] || sdx_error "knowledge-links.yaml(application) 条目缺少 app_label（必填）: $f"
        printf '    app_name: "%s"\n' "$(_knowledge_link_yaml_escape_dq "${_apps[i]}")"
        printf '    app_label: "%s"\n' "$(_knowledge_link_yaml_escape_dq "$lab")"
      fi
    done
  } >"$f"
}

# -----------------------------------------------------------------------------
# 登记 path：Git 优先 remote URL，否则仓库根路径 / 文件系统路径
# -----------------------------------------------------------------------------

# 打印 origin 或第一个可用的 remote URL；若无则返回 1 且无输出
knowledge_link_git_remote_url_prefer_origin() {
  local top="${1:?}" git_dir cfg url
  git_dir=''
  if [[ -d "$top/.git" ]]; then
    git_dir="$top/.git"
  elif [[ -f "$top/.git" ]]; then
    git_dir="$(sed -n 's/^gitdir: //p' "$top/.git" | head -n 1)"
    [[ -n "$git_dir" ]] || return 1
    [[ "$git_dir" == /* ]] || git_dir="$top/$git_dir"
  else
    return 1
  fi
  cfg="$git_dir/config"
  [[ -f "$cfg" ]] || return 1
  url="$(
    awk '
      BEGIN { in_remote=0; remote=""; first_url=""; }
      /^\[remote "[^"]+"\]$/ {
        in_remote=1;
        remote=$0;
        sub(/^\[remote "/, "", remote);
        sub(/"\]$/, "", remote);
        next;
      }
      /^\[.*\]$/ { in_remote=0; remote=""; next; }
      in_remote && /^[[:space:]]*url[[:space:]]*=[[:space:]]*/ {
        u=$0;
        sub(/^[[:space:]]*url[[:space:]]*=[[:space:]]*/, "", u);
        if (remote == "origin") { print u; exit 0; }
        if (first_url == "") { first_url=u; }
      }
      END { if (first_url != "") print first_url; }
    ' "$cfg"
  )"
  [[ -n "$url" ]] || return 1
  printf '%s\n' "$url"
}

# 给定已存在的本地目录：得到与 link 时一致的登记字符串（用于去重 / unlink）
knowledge_link_register_value_from_dir() {
  local dir="${1:?}" resolved top url
  resolved="$(cd -P "$dir" 2>/dev/null && pwd)" || {
    printf '%s\n' "$dir"
    return 0
  }
  if [[ -d "$resolved/.git" || -f "$resolved/.git" ]]; then
    top="$resolved"
  else
    printf '%s\n' "$resolved"
    return 0
  fi
  url="$(knowledge_link_git_remote_url_prefer_origin "$top" || true)"
  if [[ -n "$url" ]]; then
    url="$(strip_trailing_slash "$url")"
    printf '%s\n' "$url"
    return 0
  fi
  printf '%s\n' "$(strip_trailing_slash "$top")"
}

# 将「用户传入的 --target」规范为与已登记项可比对的身份串
knowledge_link_identity_from_raw_target() {
  local raw="${1:?}" p
  if knowledge_link_value_looks_like_git_remote "$raw"; then
    printf '%s\n' "$(strip_trailing_slash "$raw")"
    return 0
  fi
  p="$(normalize_target_repo_root "$raw")" || return 1
  if [[ -d "$p" ]]; then
    knowledge_link_register_value_from_dir "$p"
  else
    printf '%s\n' "$(strip_trailing_slash "$p")"
  fi
}

# 将「已登记的一条 repository + path」规范为身份串（与 REGISTER_KEY / --target 比对）
knowledge_link_identity_from_stored_entry() {
  local repo="${1:-}" stored_path="${2:?}"
  local exp
  if [[ -n "$repo" ]]; then
    printf '%s\n' "$(strip_trailing_slash "$repo")"
    return 0
  fi
  exp="$(knowledge_link_expand_stored_path "$stored_path")"
  if [[ -d "$exp" ]]; then
    knowledge_link_register_value_from_dir "$exp"
  else
    printf '%s\n' "$(strip_trailing_slash "$exp")"
  fi
}

# -----------------------------------------------------------------------------
# 应用槽位 application-${APPNAME}（自 DOC_ROOT 下 application-APPNAME 模板生成）
# -----------------------------------------------------------------------------

# 校验并规范化 app_name（小写）；非法则报错
knowledge_link_validate_app_name() {
  local raw="${1:?}" base
  base="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]')"
  [[ -n "$base" ]] || {
    printf '错误: app_name 不能为空\n' >&2
    return 1
  }
  if [[ ! "$base" =~ ^[a-z0-9][a-z0-9_.-]*$ ]]; then
    printf '错误: 非法 app_name: %s（仅允许 a-z0-9._-）\n' "$raw" >&2
    return 1
  fi
  printf '%s\n' "$base"
}

# 从目标仓库根推断应用标识：优先 Git 仓库根目录名，否则为路径 basename（无用户指定时用）
knowledge_link_guess_app_name() {
  local root="${1:?}" top base
  top="$(cd -P "$root" 2>/dev/null && pwd)" || top="$root"
  base="$(basename "$top")"
  knowledge_link_validate_app_name "$base"
}

# 将模板目录中的占位符替换为实际 APPNAME（仅处理常见文本后缀）
knowledge_link_apply_app_slot_substitutions() {
  local dest="${1:?}" app="${2:?}" f tmp
  while IFS= read -r f; do
    [[ -f "$f" ]] || continue
    case "$f" in
      *.md|*.yaml|*.yml) ;;
      *) continue ;;
    esac
    tmp="${f}.tmp.$$"
    sed \
      -e "s/CHANGE LOG - APPNAME/CHANGE LOG - ${app}/g" \
      -e "s/application-{app-name}/application-${app}/g" \
      -e "s/{app-name}/${app}/g" \
      -e "s/\`APPNAME\`/\`${app}\`/g" \
      "$f" >"$tmp" && mv "$tmp" "$f"
  done < <(find "$dest" -type f 2>/dev/null)
}

# 在源 DOC_ROOT 下生成 application-${APPNAME}（参考 application-APPNAME 模板）
knowledge_link_ensure_application_slot() {
  local doc_root="${1:?}" app="${2:?}"
  local dr tpl dest
  dr="$(_knowledge_link_doc_root_abs_ns "$doc_root")"
  tpl="${dr}/application-APPNAME"
  dest="${dr}/application-${app}"
  [[ -d "$tpl" ]] || sdx_error "源 DOC_ROOT 下缺少模板目录: $tpl"
  if [[ -d "$dest" ]]; then
    return 0
  fi
  if [[ "$DRY" == '1' ]]; then
    sdx_log "[dry-run] 将自模板创建目录: %s → %s" "$tpl" "$dest"
    return 0
  fi
  cp -R "$tpl" "$dest"
  knowledge_link_apply_app_slot_substitutions "$dest" "$app"
}

# -----------------------------------------------------------------------------
# 系统槽位 system-${SYSNAME}（自 DOC_ROOT 下 system-SYSNAME 模板生成）
# -----------------------------------------------------------------------------

knowledge_link_validate_sys_name() {
  local raw="${1:?}" base
  base="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]')"
  [[ -n "$base" ]] || {
    printf '错误: sys_name 不能为空\n' >&2
    return 1
  }
  if [[ ! "$base" =~ ^[a-z0-9][a-z0-9_.-]*$ ]]; then
    printf '错误: 非法 sys_name: %s（仅允许 a-z0-9._-）\n' "$raw" >&2
    return 1
  fi
  printf '%s\n' "$base"
}

knowledge_link_guess_sys_name() {
  local root="${1:?}" top base
  top="$(cd -P "$root" 2>/dev/null && pwd)" || top="$root"
  base="$(basename "$top")"
  knowledge_link_validate_sys_name "$base"
}

knowledge_link_apply_sys_slot_substitutions() {
  local dest="${1:?}" sys="${2:?}" f tmp
  while IFS= read -r f; do
    [[ -f "$f" ]] || continue
    case "$f" in
      *.md|*.yaml|*.yml) ;;
      *) continue ;;
    esac
    tmp="${f}.tmp.$$"
    sed \
      -e "s/CHANGE LOG - SYSNAME/CHANGE LOG - ${sys}/g" \
      -e "s/system-{SYSNAME}/system-${sys}/g" \
      -e "s/system-SYSNAME/system-${sys}/g" \
      -e "s/SYSNAME/${sys}/g" \
      "$f" >"$tmp" && mv "$tmp" "$f"
  done < <(find "$dest" -type f 2>/dev/null)
}

knowledge_link_ensure_system_slot() {
  local doc_root="${1:?}" sys="${2:?}"
  local dr tpl dest
  dr="$(_knowledge_link_doc_root_abs_ns "$doc_root")"
  tpl="${dr}/system-SYSNAME"
  dest="${dr}/system-${sys}"
  [[ -d "$tpl" ]] || sdx_error "源 DOC_ROOT 下缺少模板目录: $tpl"
  if [[ -d "$dest" ]]; then
    return 0
  fi
  if [[ "$DRY" == '1' ]]; then
    sdx_log "[dry-run] 将自模板创建目录: %s → %s" "$tpl" "$dest"
    return 0
  fi
  cp -R "$tpl" "$dest"
  knowledge_link_apply_sys_slot_substitutions "$dest" "$sys"
}

# 从登记 identity（repository URL 或已展开本地路径）推断 APPNAME，供旧数据或无 app_name 时 unlink 删槽位
knowledge_link_app_name_from_register_key() {
  local key="${1:?}" base
  if [[ -d "$key" ]]; then
    knowledge_link_guess_app_name "$key"
    return
  fi
  base="${key##*/}"
  base="${base%.git}"
  base="${base%%\?*}"
  base="${base%%#*}"
  base="$(printf '%s' "$base" | tr '[:upper:]' '[:lower:]')"
  [[ -n "$base" ]] || return 1
  [[ "$base" =~ ^[a-z0-9][a-z0-9_.-]*$ ]] || return 1
  printf '%s\n' "$base"
}

# 解析工程根（与 docs-install 写入 .docsconfig 的 REPO_ROOT 推导一致，供 .docs-init 备份路径）
knowledge_link_repo_root_for_backup() {
  local doc_root="${1:?}" dr rr
  dr="$(_knowledge_link_doc_root_abs_ns "$doc_root")"
  rr="$(docsconfig_repo_root_from_doc_root "$dr")"
  [[ -n "$rr" ]] || rr="$(docsconfig_repo_root_fallback_from_doc_root "$dr")"
  [[ -n "$rr" ]] || return 1
  printf '%s\n' "$(strip_trailing_slash "$rr")"
}

# 备份至 REPO_ROOT/.docs-init/<stamp>/ 后移除 application-${app}/（与 docs-install 的 backup_path 同源：sdx_docs_backup_path_to_init）
knowledge_link_remove_application_slot() {
  local doc_root="${1:?}" app="${2:?}"
  local dest repo_root
  [[ -n "$app" ]] || return 0
  if [[ "$app" == 'APPNAME' ]]; then
    sdx_warn "APPNAME 为保留名，跳过删除槽位目录"
    return 0
  fi
  dest="$(_knowledge_link_doc_root_abs_ns "$doc_root")/application-${app}"
  if [[ ! -d "$dest" ]]; then
    return 0
  fi
  repo_root="$(knowledge_link_repo_root_for_backup "$doc_root")" || {
    sdx_warn "无法解析 REPO_ROOT，跳过备份，将直接删除: $dest"
    if [[ "$DRY" == '1' ]]; then
      sdx_log "[dry-run] 将删除目录: $dest"
      return 0
    fi
    rm -rf "$dest"
    sdx_info "已删除槽位目录: $dest"
    return 0
  }
  sdx_docs_backup_path_to_init "$repo_root" "$dest" "" "$DRY"
}

# =============================================================================
# CLI
# =============================================================================

DRY="${KLINK_DEFAULT_DRY_RUN}"
CMD=''
TARGET_RAW=''
CLI_APP_NAME=''

docs_link_require_value() {
  local flag="${1:?flag is required}"
  local value="${2-}"
  [[ -n "$value" ]] || sdx_error "缺少 ${flag} 值"
}

docs_link_unknown_arg() {
  local arg="${1:?arg is required}"
  sdx_error "未知参数: ${arg}"
}

docs_link_usage() {
  cat >&2 <<'EOF'
用法: ./scripts/docs-link.sh --link|--unlink --target <目标知识库仓库根> [--app-name 名] [--dry-run]

  --link / --unlink 二选一，不得同时出现。

  须在「源」知识库 Git 仓库内执行（git rev-parse 取根）。登记文件：源 .docsconfig 的 DOC_ROOT/knowledge-links.yaml

  允许边：company→system、system→application（源/目标 .docsconfig 须含合法 KNOWLEDGE_TYPE）。
  unlink 支持目标失联（路径不存在或目标仓库配置缺失）时按登记 identity 注销。

  --dry-run     仅打印将执行的操作，不写文件。
  --target      目标知识库仓库根（或已登记的 remote URL）；兼容旧参数 --path（已弃用）。
  --app-name    仅 system→application 建联有效：显式指定 YAML 中的 app_name 及槽位目录名。
                若省略：登记文件中该 path 已有 app_name 则沿用、不再推断；否则由目标本地 Git 仓库根目录名推断。
  每条 link 记录：repository（有 Git remote 时）、path（本机在 \$HOME 下为 ~/… 或 ~/，否则绝对路径；兼容旧无 ~ 的 \$HOME 相对片段）、doc_dir、application 时的 app_name 与 app_label（无 app_label 时默认等于 app_name；重复 link 时若已有 app_label 则保留）。
  system→application：在源 DOC_ROOT 下自 application-APPNAME 模板生成 application-<APPNAME>/（已存在则跳过）。
  同一 target 重复 link：不新增行，只更新已存在且 identity 相同的那条记录。
  unlink 时：注销该条目的同时将 application-<APPNAME>/ 备份到工程根 .docs-init/ 再移除（若目录存在）。

  link 同时在目标 {DOC_ROOT}/knowledge-parent.yaml 写入源仓 identity（1:1 parent）。
  变更 repository/ref/doc_dir 时改写目标 knowledge/** 中旧 HTTP 前缀；unlink 改为纯 ID 后删除该文件。

示例:
  ./scripts/docs-link.sh --target ~/workspaces/target-repo --link
  ./scripts/docs-link.sh --target ~/workspaces/target-repo --link --app-name=my-app
  ./scripts/docs-link.sh --target ~/workspaces/target-repo --unlink --dry-run
EOF
}

docs_link_parse_args() {
  while (( $# > 0 )); do
    case "$1" in
      --link)
        [[ "$CMD" == 'unlink' ]] && sdx_error "不能同时指定 --link 与 --unlink"
        [[ "$CMD" == 'link' ]] && sdx_error "重复指定 --link"
        CMD='link'
        shift
        ;;
      --unlink)
        [[ "$CMD" == 'link' ]] && sdx_error "不能同时指定 --link 与 --unlink"
        [[ "$CMD" == 'unlink' ]] && sdx_error "重复指定 --unlink"
        CMD='unlink'
        shift
        ;;
      --dry-run) DRY=1; shift ;;
      --app-name=*)
        CLI_APP_NAME="${1#*=}"
        shift
        ;;
      --app-name)
        shift
        docs_link_require_value "--app-name" "${1:-}"
        CLI_APP_NAME="$1"
        shift
        ;;
      --target=*) TARGET_RAW="${1#*=}"; shift ;;
      --target)
        shift
        docs_link_require_value "--target" "${1:-}"
        TARGET_RAW="$1"
        shift
        ;;
      --path=*)
        TARGET_RAW="${1#*=}"
        sdx_warn "--path 已弃用，请改用 --target"
        shift
        ;;
      --path)
        shift
        docs_link_require_value "--path" "${1:-}"
        TARGET_RAW="$1"
        sdx_warn "--path 已弃用，请改用 --target"
        shift
        ;;
      -h|--help)
        docs_link_usage
        exit 0
        ;;
      *)
        docs_link_unknown_arg "$1"
        ;;
    esac
  done
}

docs_link_parse_args "$@"

validate_link_command "$CMD" || sdx_error "请指定 --link 或 --unlink（二选一）"
[[ -n "$TARGET_RAW" ]] || sdx_error "请指定 --target <目标仓库根>（仍兼容 --target=PATH）"

SRC_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || sdx_error "请在 Git 仓库内执行 docs-link"
SRC_CFG="$SRC_ROOT/.docsconfig"
[[ -f "$SRC_CFG" ]] || sdx_error "源仓库缺少 .docsconfig: $SRC_CFG"

_sdoc='' _srepo='' _sdd='' _sar='' _sads='' _skt=''
docsconfig_read_into "$SRC_CFG" _sdoc _srepo _sdd _sar _sads _skt || sdx_error "无法解析源 .docsconfig"
[[ -n "$_sdoc" ]] || sdx_error "源 .docsconfig 缺少 DOC_ROOT"
[[ -n "$_skt" ]] || sdx_error "源 .docsconfig 缺少 KNOWLEDGE_TYPE"
docsconfig_validate_knowledge_type "$_skt" || exit 1

expect_target=''
LIST_FILE="$_sdoc/knowledge-links.yaml"
case "$_skt" in
  company) expect_target='system' ;;
  system)  expect_target='application' ;;
  *) sdx_error "源 KNOWLEDGE_TYPE=${_skt} 不支持建联（仅 company 或 system 可作为源）" ;;
esac

TARGET_KEY="$(normalize_target_repo_root "$TARGET_RAW")" || sdx_error "目标路径非法: $TARGET_RAW"
REGISTER_KEY=''
REGISTER_REPO=''
REGISTER_PATH_STORED=''
TARGET_DOC_DIR=''
TARGET_APP_NAME=''
TARGET_APP_LABEL=''
TARGET_SYS_NAME=''
TARGET_SYS_LABEL=''
matched_idx=-1

if [[ "$CMD" == 'link' ]]; then
  TGT_ROOT="$(cd -P "$TARGET_KEY" 2>/dev/null && pwd)" || sdx_error "目标路径不存在或不可进入: $TARGET_KEY"
  TGT_CFG="$TGT_ROOT/.docsconfig"
  [[ -f "$TGT_CFG" ]] || sdx_error "目标仓库缺少 .docsconfig: $TGT_CFG"

  _tdoc='' _trepo='' _tdd='' _tar='' _tads='' _tkt=''
  docsconfig_read_into "$TGT_CFG" _tdoc _trepo _tdd _tar _tads _tkt || sdx_error "无法解析目标 .docsconfig"
  [[ -n "$_tkt" ]] || sdx_error "目标 .docsconfig 缺少 KNOWLEDGE_TYPE"
  docsconfig_validate_knowledge_type "$_tkt" || exit 1
  [[ "$_tkt" == "$expect_target" ]] || sdx_error "目标须为 ${expect_target} 知识库（KNOWLEDGE_TYPE=${_tkt}）"
  REGISTER_KEY="$(knowledge_link_register_value_from_dir "$TGT_ROOT")"
  REGISTER_REPO="$(knowledge_link_git_remote_url_prefer_origin "$TGT_ROOT" || true)"
  [[ -n "$REGISTER_REPO" ]] || sdx_error "目标仓库缺少 Git remote URL（repository 必填）。请为目标仓库配置 origin（或任一 remote）后重试: $TGT_ROOT"
  TARGET_DOC_DIR="$expect_target"
  REGISTER_PATH_STORED="$(knowledge_link_stored_path_from_absolute "$TGT_ROOT")"
else
  REGISTER_KEY="$(knowledge_link_identity_from_raw_target "$TARGET_RAW")" || sdx_error "目标路径非法: $TARGET_RAW"
  [[ -z "$CLI_APP_NAME" ]] || sdx_warn "--app-name 仅在 --link 时有效，已忽略"
fi

declare -a repos=() paths=() doc_dirs=() app_names=() app_labels=()
knowledge_links_load_into_arrays "$LIST_FILE" paths repos doc_dirs app_names app_labels

have=0
new_identity="${REGISTER_KEY}"
for i in "${!paths[@]}"; do
  if [[ "$(knowledge_link_identity_from_stored_entry "${repos[i]:-}" "${paths[i]}")" == "$new_identity" ]]; then
    have=1
    matched_idx=$i
    break
  fi
done

# application 槽位：app_name 优先级为 --app-name > 登记文件中已有 app_name > Git 路径推断
if [[ "$CMD" == 'link' && "$expect_target" == 'application' ]]; then
  if [[ -n "$CLI_APP_NAME" ]]; then
    TARGET_APP_NAME="$(knowledge_link_validate_app_name "$CLI_APP_NAME")" || exit 1
  elif [[ "$have" -eq 1 && "$matched_idx" -ge 0 && -n "${app_names[matched_idx]:-}" ]]; then
    TARGET_APP_NAME="$(knowledge_link_validate_app_name "${app_names[matched_idx]}")" || exit 1
  else
    TARGET_APP_NAME="$(knowledge_link_guess_app_name "$TGT_ROOT")" || exit 1
  fi
  knowledge_link_ensure_application_slot "$_sdoc" "$TARGET_APP_NAME"
  if [[ "$have" -eq 1 && "$matched_idx" -ge 0 && -n "${app_labels[matched_idx]:-}" ]]; then
    TARGET_APP_LABEL="${app_labels[matched_idx]}"
  else
    [[ -n "$TARGET_APP_NAME" ]] && TARGET_APP_LABEL="$TARGET_APP_NAME"
  fi
elif [[ "$CMD" == 'link' && "$expect_target" == 'system' ]]; then
  if [[ "$have" -eq 1 && "$matched_idx" -ge 0 && -n "${app_names[matched_idx]:-}" ]]; then
    TARGET_SYS_NAME="$(knowledge_link_validate_sys_name "${app_names[matched_idx]}")" || exit 1
  else
    TARGET_SYS_NAME="$(knowledge_link_guess_sys_name "$TGT_ROOT")" || exit 1
  fi
  knowledge_link_ensure_system_slot "$_sdoc" "$TARGET_SYS_NAME"
  if [[ "$have" -eq 1 && "$matched_idx" -ge 0 && -n "${app_labels[matched_idx]:-}" ]]; then
    TARGET_SYS_LABEL="${app_labels[matched_idx]}"
  else
    [[ -n "$TARGET_SYS_NAME" ]] && TARGET_SYS_LABEL="$TARGET_SYS_NAME"
  fi
elif [[ "$CMD" == 'link' && "$expect_target" != 'application' && -n "$CLI_APP_NAME" ]]; then
  sdx_warn "--app-name 仅用于 system→application 建联，已忽略"
fi

docs_link_execute_link() {
  local link_is_update
  local link_info=''
  local link_loc=''
  local link_verb='已登记'

  link_is_update=$have
  if [[ "$have" -eq 1 ]]; then
    repos[matched_idx]="$REGISTER_REPO"
    paths[matched_idx]="$REGISTER_PATH_STORED"
    doc_dirs[matched_idx]="$TARGET_DOC_DIR"
    if [[ "$TARGET_DOC_DIR" == 'system' ]]; then
      app_names[matched_idx]="${TARGET_SYS_NAME:-}"
      app_labels[matched_idx]="${TARGET_SYS_LABEL:-}"
    else
      app_names[matched_idx]="${TARGET_APP_NAME:-}"
      app_labels[matched_idx]="${TARGET_APP_LABEL:-}"
    fi
  else
    repos+=("$REGISTER_REPO")
    paths+=("$REGISTER_PATH_STORED")
    doc_dirs+=("$TARGET_DOC_DIR")
    if [[ "$TARGET_DOC_DIR" == 'system' ]]; then
      app_names+=("${TARGET_SYS_NAME:-}")
      app_labels+=("${TARGET_SYS_LABEL:-}")
    else
      app_names+=("${TARGET_APP_NAME:-}")
      app_labels+=("${TARGET_APP_LABEL:-}")
    fi
  fi

  knowledge_links_write_quads "$LIST_FILE" repos paths doc_dirs app_names app_labels
  docs_link_write_child_parent

  [[ "$link_is_update" -eq 1 ]] && link_verb='已更新登记'
  if [[ "$TARGET_DOC_DIR" == 'system' && -n "$TARGET_SYS_NAME" ]]; then
    link_info=" (doc_dir=system, system-${TARGET_SYS_NAME})"
  elif [[ -n "$TARGET_APP_NAME" && -n "$TARGET_DOC_DIR" ]]; then
    link_info=" (doc_dir=${TARGET_DOC_DIR}, application-${TARGET_APP_NAME})"
  elif [[ -n "$TARGET_APP_NAME" ]]; then
    link_info=" (application-${TARGET_APP_NAME})"
  elif [[ -n "$TARGET_DOC_DIR" ]]; then
    link_info=" (doc_dir=${TARGET_DOC_DIR})"
  fi
  [[ -n "$REGISTER_REPO" ]] && link_loc=" repository=${REGISTER_REPO}"
  link_loc="${link_loc} path=${REGISTER_PATH_STORED}"
  printf '%s: %s → identity=%s%s%s\n' "$link_verb" "$LIST_FILE" "$REGISTER_KEY" "$link_loc" "$link_info"
}

docs_link_execute_unlink() {
  local unlink_app_name=''
  local exp=''
  local i
  declare -a newr=() newp=() newd=() newa=() newl=()

  [[ "$have" -eq 0 ]] && { printf '提示: 未找到登记项，跳过: %s\n' "$REGISTER_KEY" >&2; exit 0; }
  docs_link_unlink_child_parent
  if [[ "$matched_idx" -ge 0 && "$_skt" == 'system' ]]; then
    unlink_app_name="${app_names[matched_idx]:-}"
    if [[ -z "$unlink_app_name" ]]; then
      if [[ -n "${repos[matched_idx]:-}" ]]; then
        unlink_app_name="$(knowledge_link_app_name_from_register_key "${repos[matched_idx]}")" || unlink_app_name=''
      else
        exp="$(knowledge_link_expand_stored_path "${paths[matched_idx]}")"
        unlink_app_name="$(knowledge_link_app_name_from_register_key "$exp")" || unlink_app_name=''
      fi
    fi
  fi

  for i in "${!paths[@]}"; do
    [[ "$(knowledge_link_identity_from_stored_entry "${repos[i]:-}" "${paths[i]}")" == "$new_identity" ]] && continue
    newr+=("${repos[i]:-}")
    newp+=("${paths[i]}")
    newd+=("${doc_dirs[i]:-}")
    newa+=("${app_names[i]:-}")
    newl+=("${app_labels[i]:-}")
  done

  knowledge_links_write_quads "$LIST_FILE" newr newp newd newa newl
  if [[ -n "$unlink_app_name" ]]; then
    knowledge_link_remove_application_slot "$_sdoc" "$unlink_app_name"
  fi
  printf '已注销: %s 中的 %s\n' "$LIST_FILE" "$REGISTER_KEY"
}

case "$CMD" in
  link) docs_link_execute_link ;;
  unlink) docs_link_execute_unlink ;;
esac
