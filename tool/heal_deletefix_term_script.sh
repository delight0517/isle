#!/usr/bin/env bash
# Delete Fix term_build_*.sh — self-heal 손상·preamble 오탐 복구
set -euo pipefail

SCRIPT="${1:-$HOME/Library/Caches/dev.rogan.deletefix/term_build_isle.sh}"
if [[ ! -f "$SCRIPT" ]]; then
  echo "[heal_deletefix] 없음: $SCRIPT"
  exit 0
fi

# Delete Fix가 bash -n 실패 시 스크립트를 20줄짜리 오류 스텁으로 덮어씀 → 백업 복구
if [[ $(wc -l < "$SCRIPT" | tr -d ' ') -lt 100 ]]; then
  bak="$(ls -t "${SCRIPT}.bak."* 2>/dev/null | head -1 || true)"
  if [[ -n "$bak" && -f "$bak" ]]; then
    cp "$bak" "$SCRIPT"
    echo "[heal_deletefix] stub 감지 → 복구: $bak"
  fi
fi

python3 - "$SCRIPT" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8", errors="replace")
orig = text

text = text.replace("'/opt/homebrew/bin/flutter' pub getfi", "'/opt/homebrew/bin/flutter' pub get\nfi")
text = re.sub(r"(?m)^fifi\s*$", "fi\nfi", text)

# Multiline preamble grep (Delete Fix bug) → 단일 라인
text = text.replace(
    "/usr/bin/grep -qE \"'[^']+/flutter' pub get\nfi\"",
    '/usr/bin/grep -qF "pub getfi"',
)
text = text.replace(
    "/usr/bin/grep -qE \"/bin/wait\\b|'[^']+/flutter' pub get\nfi\"",
    '/usr/bin/grep -qE "/bin/wait\\b|pub getfi"',
)
text = text.replace(
    '/usr/bin/grep -qE "/bin/wait\\b|getfi|pub getfi"',
    '/usr/bin/grep -qE "/bin/wait\\b|pub getfi"',
)
text = text.replace(
    '/usr/bin/grep -qE "getfi|pub getfi"',
    '/usr/bin/grep -qF "pub getfi"',
)

if "# DELETEFIX_PREAMBLE_HEALED=1" not in text[:500]:
    if text.startswith("#!/bin/bash\n"):
        text = "#!/bin/bash\n# DELETEFIX_PREAMBLE_HEALED=1\n" + text[len("#!/bin/bash\n") :]

if text != orig:
    path.write_text(text, encoding="utf-8")
    print(f"[heal_deletefix] patched: {path}")
else:
    print(f"[heal_deletefix] 변경 없음: {path}")
PY

if bash -n "$SCRIPT"; then
  echo "[heal_deletefix] bash -n OK"
else
  echo "[heal_deletefix] WARN: bash -n still failing"
  exit 1
fi
