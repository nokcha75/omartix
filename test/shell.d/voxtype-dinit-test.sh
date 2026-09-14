#!/bin/bash

set -euo pipefail

source "$(dirname "$0")/base-test.sh"

for command in "$ROOT/bin/omarchy-voxtype-install" "$ROOT/bin/omarchy-voxtype-remove"; do
  bash -n "$command"
  if rg -n '\bsystemctl\b|\bsystemd-run\b' "$command"; then
    fail "$(basename "$command") has no systemd fallback"
  fi
done

rg -F '/usr/share/voxtype/voxtype.dinit' "$ROOT/bin/omarchy-voxtype-install" >/dev/null ||
  fail "Voxtype installs its dinit service definition"
rg -F 'dinitctl --user start voxtype' "$ROOT/bin/omarchy-voxtype-install" >/dev/null ||
  fail "Voxtype starts under dinit"
rg -F 'dinitctl --user stop voxtype' "$ROOT/bin/omarchy-voxtype-remove" >/dev/null ||
  fail "Voxtype stops under dinit"

pass "Voxtype lifecycle is dinit-only"
