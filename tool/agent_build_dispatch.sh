#!/usr/bin/env bash
# Isle — 빌드·설치 단일 진입점 (Cursor / Delete Fix / 에이전트 공용)
# 중복 빌드 방지 · Flutter↔네이티브 감지 · 5분 install 멈춤 진단 · Delete Fix heal
#
# Usage:
#   ./tool/agent_build_dispatch.sh                    # 자동 (연결 기기·플랫폼 감지)
#   ./tool/agent_build_dispatch.sh iphone [UDID]      # iPhone Profile 설치+콘솔
#   ./tool/agent_build_dispatch.sh iphone-install     # iPhone 설치만 (콘솔 없음)
#   ./tool/agent_build_dispatch.sh macos              # macOS 데스크톱
#   ./tool/agent_build_dispatch.sh android            # Android full flavor
#   ./tool/agent_build_dispatch.sh desktop            # Delete Fix term_build (Mac 리빌더)
#   ./tool/agent_build_dispatch.sh diagnose           # 실패 로그만 수집
#   ./tool/agent_build_dispatch.sh wait               # 다른 세션 빌드 끝날 때까지 대기
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

LOCK_FILE="${ISLE_BUILD_LOCK:-$ROOT/runtime/.agent_build.lock}"
FAILURE_LOG="$ROOT/runtime/logs/agent_build_last_failure.json"
DELETEFIX_CTX="${DELETEFIX_AGENT_CTX:-$HOME/Library/Logs/Delete Fix/agent_live_context.md}"
DELETEFIX_CTX_LOCAL="$ROOT/.deletefix/agent_live_context.md"
TERM_LOG="${DELETEFIX_TERM_LOG:-$HOME/Library/Caches/dev.rogan.deletefix/term_build_isle.log}"
INSTALL_TIMEOUT_SEC="${ISLE_INSTALL_TIMEOUT_SEC:-300}"

log() { echo "[agent_build] $*"; }
warn() { echo "[agent_build] WARN: $*" >&2; }

mkdir -p "$ROOT/runtime/logs"

# --- Flutter vs 순수 네이티브 감지 (항상 둘 다 확인) ---
detect_stack() {
  local has_flutter=0 has_ios_native=0 has_android_native=0
  [[ -f "$ROOT/pubspec.yaml" && -d "$ROOT/lib" ]] && has_flutter=1
  [[ -d "$ROOT/ios/Runner" ]] && has_ios_native=1
  [[ -d "$ROOT/android/app" ]] && has_android_native=1

  if [[ "$has_flutter" -eq 1 ]]; then
    echo "flutter"
    log "스택: Flutter (+ ios/ android/ 네이티브 브리지)"
    return 0
  fi
  if [[ "$has_ios_native" -eq 1 && "$has_flutter" -eq 0 ]]; then
    echo "swift-native"
    log "스택: 순수 Swift/iOS (pubspec.yaml 없음)"
    return 0
  fi
  echo "unknown"
  warn "프로젝트 스택 불명 — isle/ 에 pubspec.yaml 확인"
}

# --- 다른 세션 / Delete Fix 동시 빌드 감지 ---
is_external_build_running() {
  local ctx="$DELETEFIX_CTX"
  [[ -f "$ctx" ]] || ctx="$DELETEFIX_CTX_LOCAL"
  [[ -f "$ctx" ]] || return 1

  if grep -qE 'jobStatus:\s*(running|building)' "$ctx" 2>/dev/null; then
  local updated
    updated="$(grep -E '^updated:' "$ctx" | head -1 | sed 's/updated: *//')"
    if [[ -n "$updated" ]]; then
      local age_sec
      age_sec=$(( $(date +%s) - $(date -j -f "%Y-%m-%dT%H:%M:%S" "${updated%.*}" +%s 2>/dev/null || echo 0) ))
      if [[ "$age_sec" -lt 600 ]]; then
        return 0
      fi
    else
      return 0
    fi
  fi
  return 1
}

acquire_lock() {
  if [[ -f "$LOCK_FILE" ]]; then
    local pid
    pid="$(cat "$LOCK_FILE" 2>/dev/null || true)"
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      warn "빌드 잠금 중 (pid=$pid). 대기: $0 wait"
      return 1
    fi
    rm -f "$LOCK_FILE"
  fi
  echo "$$" > "$LOCK_FILE"
  trap 'rm -f "$LOCK_FILE"' EXIT INT TERM
}

wait_for_clear() {
  local max_wait="${1:-600}"
  local waited=0
  while [[ "$waited" -lt "$max_wait" ]]; do
    if [[ ! -f "$LOCK_FILE" ]] && ! is_external_build_running; then
      log "빌드 슬롯 비었음 (${waited}s 대기 후)"
      return 0
    fi
    log "다른 세션/Delete Fix 빌드 중… ${waited}s / ${max_wait}s"
    sleep 10
    waited=$((waited + 10))
  done
  warn "대기 시간 초과 — 강제 진행하려면 rm $LOCK_FILE"
  return 1
}

purge_deletefix_backups() {
  find "${PUB_CACHE:-$HOME/.pub-cache}/hosted/pub.dev" -name '*.deletefixbak.*' -print -delete 2>/dev/null || true
}

heal_deletefix() {
  "$ROOT/tool/heal_deletefix_term_script.sh" 2>/dev/null || true
}

collect_failure() {
  local target="$1" exit_code="$2" reason="$3"
  local ctx="$DELETEFIX_CTX"
  [[ -f "$ctx" ]] || ctx="$DELETEFIX_CTX_LOCAL"
  local tail=""
  [[ -f "$TERM_LOG" ]] && tail="$(tail -80 "$TERM_LOG" 2>/dev/null | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null || tail -80 "$TERM_LOG")"

  python3 - "$FAILURE_LOG" "$target" "$exit_code" "$reason" "$ctx" "$TERM_LOG" <<'PY'
import json, sys, time
from pathlib import Path

out, target, code, reason, ctx_path, term_log = sys.argv[1:7]
ctx = Path(ctx_path).read_text(encoding="utf-8", errors="replace") if Path(ctx_path).is_file() else ""
term = Path(term_log).read_text(encoding="utf-8", errors="replace")[-12000:] if Path(term_log).is_file() else ""

payload = {
    "at": time.strftime("%Y-%m-%dT%H:%M:%S"),
    "target": target,
    "exitCode": int(code),
    "reason": reason,
    "deleteFixContext": ctx[-4000:],
    "terminalLogTail": term[-8000:],
    "hints": [],
}
if "pub getfi" in term or "getfi" in term:
    payload["hints"].append("heal_deletefix_term_script.sh 실행 (pub getfi 손상)")
if "signal 11" in term or "SIGSEGV" in term:
    payload["hints"].append("Flutter Debug+devicectl 금지 → Profile 빌드 (deletefix_launch.sh)")
if ".deletefixbak" in term:
    payload["hints"].append("pub-cache .deletefixbak.* 삭제")
if "install" in reason.lower() and code != 0:
    payload["hints"].append("devicectl install 5분 초과 시 USB·신뢰·용량·서명 확인")

Path(out).write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
print(f"[agent_build] failure log → {out}")
PY
}

run_build_script() {
  local label="$1"
  shift
  log "$label (devicectl install cap=${INSTALL_TIMEOUT_SEC}s via devicectl_install.sh)"
  set +e
  "$@"
  local ec=$?
  set -e
  if [[ "$ec" -ne 0 ]]; then
    local reason="command failed"
    if [[ "$ec" -eq 124 ]]; then
      reason="install hung >${INSTALL_TIMEOUT_SEC}s"
      warn "install ${INSTALL_TIMEOUT_SEC}s 초과 — USB 재연결·iPhone 잠금 해제·Xcode 서명 확인"
    fi
    collect_failure "$label" "$ec" "$reason"
    heal_deletefix
    purge_deletefix_backups
    return "$ec"
  fi
}

resolve_iphone_device() {
  local d="${1:-}"
  if [[ -n "$d" ]]; then
    echo "$d"
    return 0
  fi
  flutter devices 2>/dev/null | awk '/ios.*•/ {print $3; exit}'
}

cmd_diagnose() {
  heal_deletefix
  log "=== Delete Fix live context ==="
  local ctx="$DELETEFIX_CTX"
  [[ -f "$ctx" ]] || ctx="$DELETEFIX_CTX_LOCAL"
  [[ -f "$ctx" ]] && cat "$ctx" || warn "agent_live_context 없음"
  log "=== term_build tail ==="
  [[ -f "$TERM_LOG" ]] && tail -60 "$TERM_LOG" || warn "term log 없음"
  [[ -f "$FAILURE_LOG" ]] && log "=== last failure json ===" && cat "$FAILURE_LOG"
  detect_stack >/dev/null
}

cmd_wait() {
  wait_for_clear "${1:-600}"
}

cmd_desktop() {
  # Mac 데스크톱(Delete Fix term_build / 자체 리빌더)
  heal_deletefix
  if [[ -x "$ROOT/tool/run_term_build_isle.sh" ]]; then
    log "Delete Fix term_build (자체 리빌더)"
    exec "$ROOT/tool/run_term_build_isle.sh" "$@"
  fi
  warn "term_build 없음 → macOS flutter run 폴백"
  flutter pub get
  exec flutter run -d macos "$@"
}

cmd_macos() {
  purge_deletefix_backups
  flutter pub get
  exec flutter run -d macos "$@"
}

cmd_android() {
  purge_deletefix_backups
  flutter pub get
  log "Android full release APK (설치 테스트용)"
  flutter build apk --flavor full --release
  log "완료: build/app/outputs/flutter-apk/app-full-release.apk"
}

cmd_iphone_install() {
  local device
  device="$(resolve_iphone_device "${1:-}")"
  [[ -n "$device" ]] || { warn "iPhone 없음"; exit 1; }
  heal_deletefix
  purge_deletefix_backups
  run_build_script "iphone-install" "$ROOT/tool/install_iphone.sh" "$device"
}

cmd_iphone() {
  local device
  device="$(resolve_iphone_device "${1:-}")"
  [[ -n "$device" ]] || { warn "iPhone 없음"; exit 1; }
  heal_deletefix
  purge_deletefix_backups
  # 단일 파이프라인: build+install+콘솔 (Delete Fix 정책)
  run_build_script "iphone-console" "$ROOT/tool/deletefix_launch.sh" "$device"
}

cmd_auto() {
  local stack
  stack="$(detect_stack)"
  if [[ "$stack" == "swift-native" ]]; then
    warn "순수 네이티브 — xcodebuild 수동 또는 Delete Fix 앱 사용"
    exit 2
  fi
  local device
  device="$(resolve_iphone_device "")"
  if [[ -n "$device" ]]; then
    log "자동 → iPhone ($device)"
    cmd_iphone "$device"
  elif flutter devices 2>/dev/null | grep -q macos; then
    log "자동 → macOS"
    cmd_macos
  else
    log "자동 → desktop term_build"
    cmd_desktop
  fi
}


# --- 빌드 번호 자동 증가 ---
# 세션마다 버전 bump를 깜빡해서 재배포해도 화면에 옛 버전이 그대로 뜨는 문제가
# 반복됐다(2026-07-16 사용자 제보 — "빌드 번호가 왜 매번 안 올라가는 거야?").
# 수동으로 두 파일(pubspec.yaml/app_release_info.dart)을 맞춰 올리는 걸 사람이
# 매번 기억해야 하는 구조라 깜빡하기 쉬웠음 — 실제 빌드가 도는 서브커맨드에서는
# 항상 자동으로 buildNumber를 1 올려서 두 파일에 동시 반영한다.
bump_build_number() {
  local pubspec="$ROOT/pubspec.yaml"
  local release_info="$ROOT/lib/core/constants/app_release_info.dart"
  [[ -f "$pubspec" && -f "$release_info" ]] || return 0

  local line current_build next_build base_version
  line="$(grep -E '^version:' "$pubspec" | head -n1)"
  # macOS(BSD) sed -E는 \s를 지원 안 해서 [[:space:]]로 써야 한다(2026-07-16
  # 발견 — \s 버전으로 처음 짰다가 매치 자체가 안 돼서 조용히 스킵됐었음).
  base_version="$(echo "$line" | sed -E 's/^version: ([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)[[:space:]]*$/\1/')"
  current_build="$(echo "$line" | sed -E 's/^version: ([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)[[:space:]]*$/\2/')"
  if [[ -z "$base_version" || -z "$current_build" || ! "$current_build" =~ ^[0-9]+$ ]]; then
    warn "버전 문자열을 못 읽어서 자동 bump 스킵: '$line'"
    return 0
  fi
  next_build=$((current_build + 1))

  sed -i '' -E "s/^version: [0-9]+\.[0-9]+\.[0-9]+\+[0-9]+[[:space:]]*$/version: ${base_version}+${next_build}/" "$pubspec"
  sed -i '' -E "s/(static const buildNumber = ')[0-9]+(')/\1${next_build}\2/" "$release_info"
  log "버전 자동 bump: ${base_version}+${current_build} → ${base_version}+${next_build}"
}

main() {
  local sub="${1:-auto}"
  shift || true

  case "$sub" in
    diagnose|diag) cmd_diagnose; exit 0 ;;
    wait) cmd_wait "$@"; exit $? ;;
  esac

  if is_external_build_running; then
    log "Delete Fix 또는 다른 세션이 빌드 중 — 60s 대기 후 재시도"
    wait_for_clear 120 || exit 3
  fi

  acquire_lock || exit 4

  bump_build_number

  set +e
  case "$sub" in
    auto) cmd_auto "$@" ;;
    iphone|ios) cmd_iphone "$@" ;;
    iphone-install|install) cmd_iphone_install "$@" ;;
    macos|mac) cmd_macos "$@" ;;
    android|apk) cmd_android "$@" ;;
    desktop|term|rebuilder) cmd_desktop "$@" ;;
    *)
      warn "unknown subcommand: $sub"
      echo "Usage: $0 [auto|iphone|iphone-install|macos|android|desktop|diagnose|wait] [device-id]"
      exit 2
      ;;
  esac
  local ec=$?
  set -e

  if [[ "$ec" -ne 0 ]]; then
    collect_failure "$sub" "$ec" "command failed"
    heal_deletefix
    cmd_diagnose
  fi
  exit "$ec"
}

main "$@"
