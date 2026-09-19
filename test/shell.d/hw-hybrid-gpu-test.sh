#!/bin/bash

set -euo pipefail

source "$(dirname "$0")/base-test.sh"

hardware_check="$ROOT/bin/omarchy-hw-hybrid-gpu"

if bash "$hardware_check"; then
  fail "unsupported hybrid-GPU switching stays hidden from the Hardware menu"
fi
! rg -q '\b(supergfxctl|lspci|systemctl|dinitctl)\b' "$hardware_check" ||
  fail "the hidden hardware check has no unsupported backend probe"
pass "hybrid-GPU hardware check remains hidden on dinit"
