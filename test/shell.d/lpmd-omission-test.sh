#!/bin/bash
set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "$0")/base-test.sh"

script="$ROOT/install/hardware/intel/lpmd.sh"
packages="$ROOT/install/artix/omarchy-other.packages"
compatibility_note="$ROOT/docs/dinit-compatibility.md"

! rg -q 'omarchy-pkg-add.*intel-lpmd|\b(systemctl|dinitctl)\b' "$script" || fail "LPMD installer must not activate an unsupported service"
! rg -Fx 'intel-lpmd' "$packages" >/dev/null || fail "unsupported intel-lpmd must not be in the base package manifest"
grep -F 'Intel Low Power Mode Daemon (LPMD)' "$compatibility_note" >/dev/null || fail "missing LPMD omission note"
grep -F 'TLP and its D-Bus `tlp-pd` provider' "$script" >/dev/null || fail "missing LPMD setup fallback note"
grep -F 'tlp`/`tlp-pd' "$compatibility_note" >/dev/null || fail "missing LPMD UX fallback note"

pass "unsupported LPMD is omitted and documented"
