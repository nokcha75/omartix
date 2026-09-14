#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/base-test.sh"
for file in omarchy-hibernation-setup omarchy-launch-browser omarchy-menu-share omarchy-launch-shell omarchy-restart-shell omarchy-migrate; do
  command="$ROOT/bin/$file"
  bash -n "$command"
  if rg -n '\bsystemctl\b|\bsystemd-run\b|\bsystemd-cat\b' "$command"; then fail "$file has no systemd dependency"; fi
done
rg -F '/usr/lib/elogind/system-sleep' "$ROOT/bin/omarchy-hibernation-setup" >/dev/null || fail "hibernation uses elogind hooks"
rg -F 'ARTIX_SKIP_FILE=' "$ROOT/bin/omarchy-migrate" >/dev/null || fail "migration policy skips incompatible entries"
pass "launch and migration paths are dinit-only"
