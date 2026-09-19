#!/bin/bash

set -euo pipefail

source "$(dirname "$0")/base-test.sh"

reset="$ROOT/bin/omarchy-system-factory-reset"
finish="$ROOT/bin/omarchy-system-factory-reset-finish"
finish_artix="$ROOT/bin/omarchy-system-factory-reset-finish-artix"
service="$ROOT/install/artix/dinit/omarchy-system-factory-reset-finish"

bash -n "$reset" "$finish" "$finish_artix"

for path in "$reset" "$finish" "$finish_artix"; do
  if rg -n '\bsystemctl\b|systemd-id128|/etc/systemd' "$path"; then
    fail "$(basename "$path") has no systemd reset dependency"
  fi
done
grep -F 'dinitctl stop limine-snapper-sync' "$reset" >/dev/null ||
  fail "reset stops Limine synchronization through dinit"
grep -F 'tr -d' "$reset" >/dev/null ||
  fail "reset generates its new machine ID without systemd"
grep -F 'command = /usr/bin/omarchy-system-factory-reset-finish-artix' "$service" >/dev/null ||
  fail "dinit runs the reset-finisher adapter"
grep -F 'before = omarchy-provision-owner' "$service" >/dev/null ||
  fail "factory wipe completes before owner provisioning"
grep -F '/usr/bin/omarchy-system-factory-reset-finish' "$finish_artix" >/dev/null ||
  fail "adapter runs the existing reset worker"

pass "Omartix factory reset stages dinit services"
