#!/usr/bin/env bash
# Delete Fix Terminal 빌드 전 heal → 실행 (Isle 권장 진입점)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="${DELETEFIX_TERM_SCRIPT:-$HOME/Library/Caches/dev.rogan.deletefix/term_build_isle.sh}"

"$ROOT/tool/heal_deletefix_term_script.sh" "$SCRIPT"
exec bash "$SCRIPT" "$@"
