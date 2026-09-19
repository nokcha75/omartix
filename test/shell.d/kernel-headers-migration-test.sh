#!/bin/bash

set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

grep -Fxq '1789444024.sh' "$ROOT/migrations/artix-skip.txt" ||
  fail "Omarchy/T2 header migration is on the Artix skip list"
grep -F 'linux-omarchy' "$ROOT/migrations/1789444024.sh" >/dev/null ||
  fail "the skipped header migration keeps the upstream linux-omarchy script"
pass "linux-omarchy header migration is skipped on Artix"
