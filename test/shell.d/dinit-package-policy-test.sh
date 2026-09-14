#!/bin/bash

set -euo pipefail

source "$(dirname "$0")/base-test.sh"

for manifest in "$ROOT/install/omarchy-base.packages" "$ROOT/install/omarchy-other.packages"; do
  if rg -n 'nvidia-580xx|t2fanrd|asusctl' "$manifest"; then
    fail "$(basename "$manifest") has no unsupported systemd-only package"
  fi
done

rg -Fx 'nvidia-utils-dinit' "$ROOT/install/omarchy-other.packages" >/dev/null ||
  fail "NVIDIA GSP support includes its dinit compatibility package"
rg -Fx 'ntp' "$ROOT/install/omarchy-other.packages" >/dev/null ||
  fail "dinit time update has an ntp provider"
if rg -n '\bsystemctl\b|\bsystemd-run\b' "$ROOT/bin/omarchy-install-service-once" "$ROOT/install/hardware/nvidia.sh"; then
  fail "optional service setup has no systemd fallback"
fi
! rg -q 'install\.service\.nordvpn|omarchy-install-service-nordvpn' "$ROOT/default/omarchy/omarchy-menu.jsonc" ||
  fail "unsupported NordVPN integration is not exposed"

pass "optional package policy is dinit-only"
