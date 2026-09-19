#!/bin/bash

set -euo pipefail

source "$(dirname "$0")/base-test.sh"

dns="$ROOT/bin/omarchy-dns"

bash -n "$dns"

if rg -n '\bsystemctl\b|\bsystemd-run\b|/etc/systemd/resolved\.conf' "$dns"; then
  fail "Omartix DNS backend does not depend on systemd-resolved"
fi
grep -F 'nmcli general reload conf' "$dns" >/dev/null ||
  fail "DNS reloads NetworkManager configuration"
grep -F 'nmcli general reload dns-full' "$dns" >/dev/null ||
  fail "DNS republishes NetworkManager resolver state"
grep -F 'write_networkmanager_dns' "$dns" >/dev/null ||
  fail "DNS providers retain the NetworkManager backend"

pass "Omartix DNS uses NetworkManager without systemd-resolved"
