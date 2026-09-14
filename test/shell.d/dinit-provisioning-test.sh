#!/bin/bash

set -euo pipefail

source "$(dirname "$0")/base-test.sh"

owner="$ROOT/bin/omarchy-provision-owner"
factory_reset="$ROOT/bin/omarchy-system-factory-reset"
factory_finish="$ROOT/bin/omarchy-system-factory-reset-finish"
service="$ROOT/install/artix/dinit/omarchy-provision-owner"
factory_service="$ROOT/install/artix/dinit/omarchy-system-factory-reset-finish"

bash -n "$owner" "$factory_reset" "$factory_finish" "$service" "$factory_service" \
  "$ROOT/install/artix/config/enable-user-services.sh"
rg -F 'command = /usr/bin/openvt -c 1 -s -w -- /usr/bin/omarchy-provision-owner' "$service" >/dev/null ||
  fail "deferred owner provisioning is a dinit service"
rg -F '/etc/dinit.d/boot.d/omarchy-provision-owner' "$owner" >/dev/null ||
  fail "owner provisioning removes its dinit boot link"
rg -F 'dinitctl stop limine-snapper-sync' "$factory_reset" >/dev/null ||
  fail "factory reset stops the dinit Snapper service"
rg -F '/etc/dinit.d/boot.d/omarchy-system-factory-reset-finish' "$factory_finish" >/dev/null ||
  fail "factory reset removes its dinit service"
for file in "$owner" "$factory_reset" "$factory_finish"; do
  if rg -n '\bsystemctl\b|\bsystemd-run\b|\bloginctl\b|\btimedatectl\b|\bhostnamectl\b|\blocalectl\b' "$file"; then
    fail "$(basename "$file") has no systemd dependency"
  fi
done

pass "provisioning and factory reset are dinit-only"
