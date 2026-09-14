#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/base-test.sh"
for file in omarchy-sudo-passwordless omarchy-sudo-passwordless-expire; do
  bash -n "$ROOT/bin/$file"
  if rg -n '\bsystemctl\b|\bsystemd-run\b' "$ROOT/bin/$file"; then fail "$file has no systemd dependency"; fi
done
rg -F 'command = /usr/bin/omarchy-sudo-passwordless-expire $uid' "$ROOT/bin/omarchy-sudo-passwordless" >/dev/null || fail "expiry uses dinit service"
rg -F 'rm -f "$state_file"' "$ROOT/bin/omarchy-sudo-passwordless-expire" >/dev/null || fail "expiry revokes sudo grant"
pass "temporary passwordless sudo uses dinit expiry"
