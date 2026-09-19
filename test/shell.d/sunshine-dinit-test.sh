#!/bin/bash

set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "$0")/base-test.sh"

installer="$ROOT/bin/omarchy-install-service-sunshine"
remover="$ROOT/bin/omarchy-remove-service-sunshine"

bash -n "$installer" "$remover"

for command in "$installer" "$remover"; do
  if rg -n '\bsystemctl\b|\bsystemd-run\b' "$command"; then
    fail "$(basename "$command") has no systemd runtime path"
  fi
done

grep -F 'omarchy-pkg-add sunshine' "$installer" >/dev/null ||
  fail "Sunshine keeps the normal remote package installation path"
grep -F 'command = /usr/bin/sunshine' "$installer" >/dev/null ||
  fail "Sunshine has a user dinit service definition"
grep -F 'dinitctl --user start sunshine' "$installer" >/dev/null ||
  fail "Sunshine starts through the dinit user manager"
grep -F 'o.launch_on_start("dinitctl --user start sunshine")' "$installer" >/dev/null ||
  fail "Sunshine starts after Hyprland supplies the graphical environment"
grep -F 'dinitctl --user stop sunshine' "$remover" >/dev/null ||
  fail "Sunshine removal stops its dinit user service"
# shellcheck disable=SC2016
grep -F 'rm -f "$HOME/.config/dinit.d/sunshine"' "$remover" >/dev/null ||
  fail "Sunshine removal deletes its dinit user service definition"

pass "Sunshine uses a graphical-session dinit user service"
