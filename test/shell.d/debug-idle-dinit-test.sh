#!/bin/bash

set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "$0")/base-test.sh"

script="$ROOT/bin/omarchy-debug-idle"

grep -F 'dinitctl --user status omarchy-sleep-lock' "$script" >/dev/null ||
  fail "idle diagnostics inspect the dinit sleep-lock service"
grep -F 'elogind-inhibit.*Lock screen before suspend' "$script" >/dev/null ||
  fail "idle diagnostics find the elogind inhibitor process"
! rg -q '\bsystemctl\b|systemd-inhibit' "$script" ||
  fail "idle diagnostics have no user-systemd path"

pass "idle diagnostics target dinit and elogind"
