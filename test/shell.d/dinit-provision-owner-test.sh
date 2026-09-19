#!/bin/bash

set -euo pipefail

source "$(dirname "$0")/base-test.sh"

owner="$ROOT/bin/omarchy-provision-owner"
service="$ROOT/install/artix/dinit/omarchy-provision-owner"
autologin="$ROOT/bin/omarchy-provision-autologin-once"

bash -n "$owner" "$autologin"

if rg -n '\bsystemctl\b|systemd-firstboot|\blocalectl\b|\bhostnamectl\b|/etc/systemd' "$owner"; then
  fail "first-boot owner provisioning is dinit-only"
fi
grep -F 'command = /usr/bin/openvt -c 1 -s -w -- /usr/bin/omarchy-provision-owner' "$service" >/dev/null ||
  fail "dinit provisioning service owns tty1"
grep -F 'before = sddm' "$service" >/dev/null ||
  fail "provisioning completes before the display manager"
grep -F 'KEYMAP=%s' "$owner" >/dev/null ||
  fail "provisioning persists the selected keyboard layout"
grep -F '/etc/dinit.d/boot.d/omarchy-provision-owner' "$owner" >/dev/null ||
  fail "provisioning removes its dinit enablement after completion"
grep -F '/etc/dinit.d/boot.d/omarchy-provision-autologin-once' "$autologin" >/dev/null ||
  fail "one-time autologin cleanup removes its dinit enablement"

pass "Omartix first-boot owner provisioning uses dinit"
