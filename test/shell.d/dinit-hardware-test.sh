#!/bin/bash

set -euo pipefail

source "$(dirname "$0")/base-test.sh"

hardware_scripts=(
  "$ROOT/install/hardware/network.sh"
  "$ROOT/install/hardware/bluetooth.sh"
  "$ROOT/install/hardware/intel/lpmd.sh"
  "$ROOT/install/hardware/intel/thermald.sh"
  "$ROOT/install/hardware/apple/fix-t2.sh"
  "$ROOT/install/hardware/apple/fix-suspend-nvme.sh"
)

for script in "${hardware_scripts[@]}"; do
  bash -n "$script"
  if rg -n '\bsystemctl\b|\bsystemd-run\b' "$script"; then
    fail "$(basename "$script") does not invoke systemd"
  fi
done

grep -F 'owned by the ISO bootstrap' "$ROOT/install/hardware/network.sh" >/dev/null ||
  fail "network setup leaves base service activation to the ISO bootstrap"
grep -F 'owned by the ISO bootstrap' "$ROOT/install/hardware/bluetooth.sh" >/dev/null ||
  fail "Bluetooth setup leaves base service activation to the ISO bootstrap"
grep -F 'type = process' "$ROOT/install/hardware/apple/fix-suspend-nvme.sh" >/dev/null ||
  fail "NVMe suspend workaround uses a dinit service"

pass "hardware service setup is dinit-only"
