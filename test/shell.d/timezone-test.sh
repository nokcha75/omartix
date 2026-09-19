#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

timezone_menu="$ROOT/bin/omarchy-menu-timezone"

! rg -n '\btimedatectl\b|\bsystemctl\b|systemd-timesyncd' "$timezone_menu" ||
  fail "timezone menu has no systemd dependency"

grep -F "awk '\$1 !~ /^#/ && NF >= 3 {print \$3}' /usr/share/zoneinfo/zone.tab" "$timezone_menu" >/dev/null ||
  fail "timezone menu lists IANA zones from zoneinfo"

grep -F '[[ -e "/usr/share/zoneinfo/$timezone" ]]' "$timezone_menu" >/dev/null ||
  fail "timezone menu validates the selected zone"

grep -F 'sudo ln -sfn "/usr/share/zoneinfo/$timezone" /etc/localtime' "$timezone_menu" >/dev/null ||
  fail "timezone menu updates localtime through sudo"

grep -F "printf '%s\\n' \"\$timezone\" | sudo tee /etc/timezone >/dev/null" "$timezone_menu" >/dev/null ||
  fail "timezone menu records the selected zone"

grep -F 'omarchy-shell -q omarchy.clock refresh' "$timezone_menu" >/dev/null ||
  fail "timezone menu refreshes the namespaced clock IPC target"

! grep -F 'omarchy-shell -q Clock refresh' "$timezone_menu" >/dev/null ||
  fail "timezone menu no longer refreshes the retired Clock IPC target"

pass "timezone menu refreshes clock after timezone changes"
