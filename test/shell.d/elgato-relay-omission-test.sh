#!/bin/bash

set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "$0")/base-test.sh"

hardware_all="$ROOT/install/artix/hardware/all.sh"
migration="$ROOT/migrations/1788862626.sh"
compatibility_note="$ROOT/docs/dinit-compatibility.md"
menu="$ROOT/default/omarchy/omarchy-menu.jsonc"
contributing="$ROOT/CONTRIBUTING.md"
readme="$ROOT/README.md"

if rg -n 'fix-elgato-camlink-4k\.sh|v4l2-relayd' "$hardware_all" >/dev/null; then
  fail "Omartix does not install the unsupported Elgato relay"
fi
pass "Omartix omits the unsupported Elgato relay from fresh installs"

bash -euo pipefail "$migration" >/dev/null ||
  fail "Elgato relay migration succeeds without an unavailable package"
if rg -n '\b(systemctl|dinitctl|sudo)\b|omarchy-pkg-add.*v4l2-relayd' "$migration" >/dev/null; then
  fail "Elgato relay migration has no unsupported service-manager path"
fi
pass "Elgato relay migration leaves capture devices unchanged"

grep -F 'Elgato Cam Link 4K automatic 16:9 virtual-camera relay' "$compatibility_note" >/dev/null ||
  fail "the Elgato omission is documented"
grep -F "Artix packages \`v4l2-relayd\` with a dinit service" "$compatibility_note" >/dev/null ||
  fail "the Elgato omission records a restoration condition"
pass "Elgato omission has a maintained compatibility note"

! rg -q 'trigger\.hardware\.hybrid-gpu' "$menu" ||
  fail "Omartix hides unsupported ASUS hybrid-GPU switching from the Hardware menu"
grep -F 'ASUS hybrid-GPU mode switching' "$compatibility_note" >/dev/null ||
  fail "the ASUS hybrid-GPU omission is documented"
grep -F "Artix packages \`supergfxctl\` with a reviewed dinit service" "$compatibility_note" >/dev/null ||
  fail "the ASUS hybrid-GPU omission records a restoration condition"
pass "ASUS hybrid-GPU switching is hidden with a restoration condition"

for guide in "$contributing" "$readme"; do
  grep -F 'dinit-compatibility.md' "$guide" >/dev/null ||
    fail "$(basename "$guide") directs contributors to dinit compatibility policy"
done
pass "contributor-facing files expose the dinit compatibility policy"
