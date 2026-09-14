#!/bin/bash

set -euo pipefail

source "$(dirname "$0")/base-test.sh"

for action in reboot shutdown suspend hibernate; do
  command="$ROOT/bin/omarchy-system-$action"
  bash -n "$command"
  grep -F '/usr/bin/loginctl' "$command" >/dev/null ||
    fail "$action uses elogind's loginctl action"
  if grep -Eq '\bsystemctl\b|\bsystemd-run\b' "$command"; then
    fail "$action has no systemd power fallback"
  fi
done

grep -F 'exec /usr/bin/loginctl reboot' "$ROOT/bin/omarchy-system-reboot" >/dev/null ||
  fail "reboot targets elogind"
grep -F 'exec /usr/bin/loginctl poweroff' "$ROOT/bin/omarchy-system-shutdown" >/dev/null ||
  fail "shutdown targets elogind"
grep -F 'exec /usr/bin/loginctl suspend' "$ROOT/bin/omarchy-system-suspend" >/dev/null ||
  fail "suspend targets elogind"
grep -F 'exec /usr/bin/loginctl hibernate' "$ROOT/bin/omarchy-system-hibernate" >/dev/null ||
  fail "hibernate targets elogind"

pass "all power commands use dinit-compatible elogind actions"
