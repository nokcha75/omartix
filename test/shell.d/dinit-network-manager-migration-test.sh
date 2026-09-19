#!/bin/bash

set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "$0")/base-test.sh"

migration="$ROOT/migrations/1782002156.sh"
hardware_network="$ROOT/install/hardware/network.sh"
test_log=$(mktemp)
trap 'rm -f "$test_log"' EXIT

(
  # These functions are invoked indirectly by the sourced migration.
  # shellcheck disable=SC2329
  omarchy-pkg-add() { printf 'pkg:%s\n' "$*" >>"$test_log"; }
  # shellcheck disable=SC2329
  sudo() { "$@"; }
  # shellcheck disable=SC2329
  dinitctl() { printf 'dinit:%s\n' "$*" >>"$test_log"; }

  # shellcheck disable=SC1090
  source "$migration"
)

grep -Fx 'pkg:networkmanager networkmanager-dinit' "$test_log" >/dev/null ||
  fail "network migration installs the Artix NetworkManager service package"
grep -Fx 'dinit:enable NetworkManager' "$test_log" >/dev/null ||
  fail "network migration enables NetworkManager through dinit"
grep -Fx 'dinit:start NetworkManager' "$test_log" >/dev/null ||
  fail "network migration starts NetworkManager without a reboot"
pass "network migration moves Omartix onto NetworkManager through dinit"

if rg -n '\bsystemctl\b|systemd-networkd|systemd-resolved' "$migration" "$hardware_network" >/dev/null; then
  fail "network setup has no systemd network-manager path"
fi
pass "network setup keeps dinit as the only service-manager path"
