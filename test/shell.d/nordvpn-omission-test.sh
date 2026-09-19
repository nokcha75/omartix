#!/bin/bash

set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "$0")/base-test.sh"

installer="$ROOT/bin/omarchy-install-service-nordvpn"
menu="$ROOT/default/omarchy/omarchy-menu.jsonc"
compatibility_note="$ROOT/docs/dinit-compatibility.md"

! rg -q 'omarchy-pkg-add|\b(systemctl|dinitctl)\b|usermod' "$installer" ||
  fail "NordVPN installer does not attempt unavailable packages or services"
! rg -q 'install\.service\.nordvpn' "$menu" ||
  fail "NordVPN is hidden from the Install menu"
grep -F 'NordVPN | Hidden from the Install menu' "$compatibility_note" >/dev/null ||
  fail "NordVPN omission is documented"
grep -F 'Artix packages NordVPN with a reviewed dinit service' "$compatibility_note" >/dev/null ||
  fail "NordVPN omission records a restoration condition"

pass "NordVPN is omitted until Artix provides a dinit-supported package"
