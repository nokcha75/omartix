#!/bin/bash

set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "$0")/base-test.sh"

script="$ROOT/bin/omarchy-dev-install-ydoo"

grep -F 'command = /usr/bin/ydotoold' "$script" >/dev/null ||
  fail "ydotool installer writes a persistent dinit daemon"
grep -F 'dinitctl --user start ydotool' "$script" >/dev/null ||
  fail "ydotool installer starts the dinit user service"
grep -F 'dinitctl --user is-started ydotool' "$script" >/dev/null ||
  fail "ydotool installer verifies the dinit user service"
! rg -q '\bsystemctl\b|\bsystemd-run\b' "$script" ||
  fail "ydotool installer has no systemd path"

pass "ydotool uses a persistent dinit user service"
