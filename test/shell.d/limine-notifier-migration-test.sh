#!/bin/bash

set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "$0")/base-test.sh"

migration="$ROOT/migrations/1782049344.sh"
test_home=$(mktemp -d)
trap 'rm -rf "$test_home"' EXIT

HOME="$test_home" bash -euo pipefail "$migration" >/dev/null ||
  fail "Limine notifier migration completes without a service manager"

autostart_file="$test_home/.config/autostart/limine-snapper-notify.desktop"
grep -Fx '[Desktop Entry]' "$autostart_file" >/dev/null ||
  fail "Limine notifier migration writes an autostart override"
grep -Fx 'Hidden=true' "$autostart_file" >/dev/null ||
  fail "Limine notifier migration disables the notifier"
pass "Limine notifier migration disables the autostart entry"

if rg -n '\bsystemctl\b|\bdinitctl\b' "$migration" >/dev/null; then
  fail "Limine notifier migration has no service-manager dependency"
fi
pass "Limine notifier migration is desktop-autostart only"
