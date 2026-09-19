#!/bin/bash

set -euo pipefail

source "$(dirname "$0")/base-test.sh"

migration="$ROOT/migrations/1788662350.sh"

bash "$migration" >/dev/null ||
  fail "retired hybrid-GPU migration is a successful dinit no-op"
! rg -q '\b(systemctl|dinitctl|sudo|supergfxctl)\b' "$migration" ||
  fail "retired hybrid-GPU migration has no service or package action"
grep -F 'docs/dinit-compatibility.md' "$migration" >/dev/null ||
  fail "retired hybrid-GPU migration explains its deliberate omission"
pass "retired hybrid-GPU migration leaves dinit systems unchanged"
