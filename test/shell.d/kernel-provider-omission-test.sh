#!/bin/bash
set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "$0")/base-test.sh"

packages="$ROOT/install/artix/omarchy-other.packages"
hardware="$ROOT/install/artix/hardware/all.sh"
compatibility_note="$ROOT/docs/dinit-compatibility.md"

! rg -Fx 'linux-ptl' "$packages" >/dev/null || fail "linux-ptl must not be in the ISO package manifest"
! rg -Fx 'linux-ptl-headers' "$packages" >/dev/null || fail "linux-ptl-headers must not be in the ISO package manifest"
! rg -Fx 'linux-omarchy' "$packages" >/dev/null || fail "linux-omarchy must not be in the ISO package manifest"
! rg -Fx 'linux-omarchy-headers' "$packages" >/dev/null || fail "linux-omarchy-headers must not be in the ISO package manifest"
rg -Fx 'linux' "$packages" >/dev/null || fail "Artix linux must remain in the ISO package manifest"
rg -Fx 'linux-headers' "$packages" >/dev/null || fail "Artix linux-headers must remain in the ISO package manifest"

[[ ! -e $ROOT/install/hardware/intel/ptl-kernel.sh ]] || fail "ptl-kernel installer must stay removed"
! rg -F 'ptl-kernel.sh' "$hardware" >/dev/null || fail "hardware install must not call ptl-kernel.sh"
! rg -F 'fix-elgato-camlink-4k.sh' "$hardware" >/dev/null || fail "hardware install must not call the Elgato script"

grep -F 'Intel Panther Lake special kernel' "$compatibility_note" >/dev/null || fail "missing Panther Lake omission note"
grep -F 'Elgato Cam Link 4K automatic 16:9 virtual-camera relay' "$compatibility_note" >/dev/null || fail "missing Elgato omission note"

pass "Artix kernel and Elgato omissions stay documented"
