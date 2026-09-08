#!/usr/bin/env bash
# agent-config.sh — 仅供 agent-install.sh source（Agent CLI 默认值、校验、.docsconfig）
# 依赖 Bash 5+；source agent/scripts/docs-core.sh

if [[ -n "${_SDX_AGENT_CONFIG_SH_LOADED:-}" ]]; then
  return 0 2>/dev/null || exit 0
fi
readonly _SDX_AGENT_CONFIG_SH_LOADED=1

readonly AGENT_CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../agent/scripts/docs-core.sh
source "${AGENT_CONFIG_DIR}/../agent/scripts/docs-core.sh"

readonly SDX_VERSION='3.0.0'

declare -A SDX_AGENT_DIR_MAP=(
  [cursor]='.cursor'
  [trae]='.trae'
  [claude]='.claude'
  [kiro]='.kiro'
  [codex]='.codex'
)

readonly SDX_DEFAULT_AGENT_SCOPE='a'
readonly SDX_DEFAULT_AGENTS_OPT='cursor'

# scope=a：hooks + rules + scripts + skills + knowledge + references
# scope=k|knowledge：仅 knowledge/ + references/
agent_scope_apply() {
  local _raw="${1:?scope}"
  local -n _ref_rules="${2:?}" _ref_skills="${3:?}" _ref_hooks="${4:?}" _ref_scripts="${5:?}" _ref_knowledge="${6:?}"
  _ref_rules=0 _ref_skills=0 _ref_hooks=0 _ref_scripts=0 _ref_knowledge=0
  case "${_raw}" in
    a|A|all)
      _ref_rules=1 _ref_skills=1 _ref_hooks=1 _ref_scripts=1 _ref_knowledge=1
      ;;
    k|K|knowledge)
      _ref_knowledge=1
      ;;
    r|R) _ref_rules=1 ;;
    s|S) _ref_skills=1 ;;
    h|H) _ref_hooks=1 ;;
    sh|SH) _ref_scripts=1 ;;
    *) return 1 ;;
  esac
}

validate_agent_scope_token() {
  [[ -n "${1:-}" ]] || return 1
  local _ir _is _ih _ish _ik
  agent_scope_apply "${1:-}" _ir _is _ih _ish _ik
}

validate_agents() { sdx_agents_validate "${1:-}"; }

normalize_agents() { sdx_agents_normalize "${1:-}"; }

agent_dirs_space_separated_for() {
  local ag d out=''
  for ag in "$@"; do
    d="$(get_agent_dir "$ag")"
    out="${out:+$out }$d"
  done
  printf '%s' "$out"
}

get_agent_dir() {
  printf '%s' "${SDX_AGENT_DIR_MAP[${1:-}]:-agent}"
}
