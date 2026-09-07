#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
python3 "$ROOT/scripts/tests/okf/test_okf_lib.py"
python3 "$ROOT/scripts/tests/okf/test_okf_cross_layer.py"
python3 "$ROOT/scripts/tests/okf/test_inject_frontmatter.py"
python3 "$ROOT/scripts/tests/okf/test_generate_index.py"
python3 "$ROOT/scripts/tests/okf/test_visualize.py"
python3 "$ROOT/scripts/tests/okf/test_validate_viz_index.py"
python3 "$ROOT/scripts/tests/okf/test_validate_bundle.py"
CASE_DIR="$ROOT/scripts/tests/okf/cases"
if [[ -d "$CASE_DIR" ]]; then
  shopt -s nullglob
  cases=( "$CASE_DIR"/*.sh )
  shopt -u nullglob
  if ((${#cases[@]})); then
    IFS=$'\n' sorted=( $(printf '%s\n' "${cases[@]}" | sort) )
    unset IFS
    for f in "${sorted[@]}"; do
      printf '>>> %s\n' "$(basename "$f")"
      bash "$f"
    done
  fi
fi
echo "[OK] okf tests passed"
