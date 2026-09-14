#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

timezone_menu="$ROOT/bin/omarchy-menu-timezone"
! grep -q 'timedatectl' "$timezone_menu" ||
  fail "timezone menu does not depend on systemd timedatectl"

grep -F 'sudo ln -sfn "/usr/share/zoneinfo/$timezone" /etc/localtime' "$timezone_menu" >/dev/null ||
  fail "timezone menu updates localtime through the zoneinfo database"

grep -F 'sudo tee /etc/timezone' "$timezone_menu" >/dev/null ||
  fail "timezone menu persists the selected timezone"

grep -F 'omarchy-shell -q omarchy.clock refresh' "$timezone_menu" >/dev/null ||
  fail "timezone menu refreshes the namespaced clock IPC target"

! grep -F 'omarchy-shell -q Clock refresh' "$timezone_menu" >/dev/null ||
  fail "timezone menu no longer refreshes the retired Clock IPC target"

pass "timezone menu refreshes clock after timezone changes"
