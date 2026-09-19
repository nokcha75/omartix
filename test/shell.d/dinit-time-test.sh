#!/bin/bash

set -euo pipefail

source "$(dirname "$0")/base-test.sh"

timezone_menu="$ROOT/bin/omarchy-menu-timezone"
time_update="$ROOT/bin/omarchy-update-time"
setup_form="$ROOT/install/provisioning/setup-form.sh"
owner_provision="$ROOT/bin/omarchy-provision-owner"
packages="$ROOT/install/artix/omarchy-other.packages"

for path in "$timezone_menu" "$time_update" "$setup_form"; do
  if rg -n '\btimedatectl\b|\bsystemctl\b|systemd-timesyncd' "$path"; then
    fail "$(basename "$path") has no systemd time dependency"
  fi
done

configure_timezone=$(sed -n '/^configure_timezone()/,/^}/p' "$owner_provision")
if rg -n '\btimedatectl\b|\bsystemctl\b|systemd-timesyncd' <<<"$configure_timezone"; then
  fail "owner timezone finalization has no systemd dependency"
fi
grep -F 'ln -sfn "/usr/share/zoneinfo/$timezone" /etc/localtime' <<<"$configure_timezone" >/dev/null ||
  fail "owner timezone finalization uses zoneinfo"

grep -F 'omarchy_timezone_list' "$setup_form" >/dev/null ||
  fail "installer lists timezones without timedatectl"
grep -F 'ntpd -gq' "$time_update" >/dev/null ||
  fail "time refresh performs one-shot NTP synchronization"
rg -Fx 'ntp' "$packages" >/dev/null ||
  fail "Artix runtime declares the official ntp provider"

pass "Omartix time and timezone paths use Artix providers"
