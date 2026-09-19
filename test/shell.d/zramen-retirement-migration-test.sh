#!/bin/bash

set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "$0")/base-test.sh"

migration="$ROOT/migrations/1785013000.sh"

bash -euo pipefail "$migration" >/dev/null ||
  fail "zram retirement migration succeeds without a service manager"
pass "zram retirement migration is a safe zramen no-op"

if rg -n '\b(systemctl|dinitctl|sudo)\b|zram-generator' "$migration" >/dev/null; then
  fail "zram retirement migration does not manage the retired generator"
fi
pass "zram retirement migration leaves zramen policy untouched"
