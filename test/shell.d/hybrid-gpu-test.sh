#!/bin/bash

set -euo pipefail

source "$(dirname "$0")/base-test.sh"

command="$ROOT/bin/omarchy-toggle-hybrid-gpu"

set +e
output=$(bash "$command" 2>&1)
status=$?
set -e

(( status != 0 )) || fail "unsupported hybrid-GPU switching does not report success"
grep -F 'ASUS hybrid-GPU switching is unavailable on Omartix.' <<<"$output" >/dev/null ||
  fail "unsupported hybrid-GPU switching explains its status"
grep -F 'docs/dinit-compatibility.md' <<<"$output" >/dev/null ||
  fail "unsupported hybrid-GPU switching links its compatibility note"
! rg -q '\b(systemctl|dinitctl|omarchy-pkg-add)\b' "$command" ||
  fail "unsupported hybrid-GPU switching does not modify packages or services"
pass "hybrid-GPU switching is safely unavailable on dinit"
