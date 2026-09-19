#!/bin/bash

set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "$0")/base-test.sh"

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

mock_bin="$test_tmp/bin"
launch_log="$test_tmp/localsend.log"
mkdir -p "$mock_bin"

cat >"$mock_bin/localsend" <<'SH'
#!/bin/bash
printf '%s\n' "$*" >>"$OMARTIX_TEST_LOCALSEND_LOG"
SH
chmod +x "$mock_bin/localsend"

wait_for_launch() {
  local expected="$1"
  local attempt=0

  while (( attempt++ < 50 )); do
    [[ -f $launch_log ]] && grep -Fx -- "$expected" "$launch_log" >/dev/null && return 0
    sleep 0.02
  done

  return 1
}

PATH="$mock_bin:$PATH" OMARTIX_TEST_LOCALSEND_LOG="$launch_log" \
  bash "$ROOT/bin/omarchy-menu-share" file /tmp/first '/tmp/second file'

wait_for_launch '--headless send /tmp/first /tmp/second file' ||
  fail "LocalSend receives every selected path through the detached launcher"
! rg -q '\b(systemd-run|systemctl|dinitctl)\b' "$ROOT/bin/omarchy-menu-share" ||
  fail "LocalSend sharing has no service-manager dependency"
grep -F 'nohup localsend --headless send' "$ROOT/bin/omarchy-menu-share" >/dev/null ||
  fail "LocalSend sharing uses a detached process"
pass "LocalSend sharing continues without systemd user services"
