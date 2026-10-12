#!/usr/bin/env bash
# Analyze only changed (or explicitly listed) Dart files — avoids full-project flutter analyze.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

collect_git_changed() {
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    return
  fi
  {
    git diff --name-only --diff-filter=ACMRTUXB HEAD 2>/dev/null || true
    git diff --name-only --diff-filter=ACMRTUXB 2>/dev/null || true
  } | grep -E '^lib/.*\.dart$|^test/.*\.dart$' | sort -u
}

FILES=()
if [[ $# -gt 0 ]]; then
  while IFS= read -r f; do
    [[ "$f" == *.dart ]] && FILES+=("$f")
  done < <(printf '%s\n' "$@")
else
  while IFS= read -r f; do
    [[ -n "$f" ]] && FILES+=("$f")
  done < <(collect_git_changed)
fi

if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "agent_verify: no Dart files (pass paths or change lib/ test/)."
  exit 0
fi

echo "agent_verify: ${#FILES[@]} file(s)"
dart analyze "${FILES[@]}"
