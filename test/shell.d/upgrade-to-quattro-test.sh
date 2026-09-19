#!/bin/bash

set -euo pipefail

source "$(dirname "$0")/base-test.sh"

upgrade_to_quattro="$ROOT/install/artix/omarchy-upgrade-to-quattro"

bash -n "$upgrade_to_quattro"

output=$("$upgrade_to_quattro" 2>&1) && fail "legacy Quattro command must fail safely"
[[ $output == *"not available on Omartix"* ]] ||
  fail "legacy Quattro command identifies Omartix"
[[ $output == *'Use `omarchy-update` for normal updates.'* ]] ||
  fail "legacy Quattro command directs users to the supported updater"

if rg -n '\b(systemctl|systemd-run|pacman -Syy|archlinux-keyring)\b' "$upgrade_to_quattro"; then
  fail "legacy Quattro command contains no Arch/systemd transition logic"
fi

pass "Quattro upgrade is a safe Omartix guidance command"
