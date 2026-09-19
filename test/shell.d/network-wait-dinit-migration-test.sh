#!/bin/bash

set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "$0")/base-test.sh"

migration="$ROOT/migrations/1784568652.sh"

bash -euo pipefail "$migration" >/dev/null ||
  fail "network wait migration succeeds without a service manager"
pass "network wait migration is a safe dinit no-op"

if rg -n '\b(systemctl|dinitctl|sudo)\b' "$migration" >/dev/null; then
  fail "network wait migration does not manage a nonexistent dinit wait service"
fi
pass "network wait migration leaves dinit boot dependencies unchanged"
