#!/bin/bash

set -euo pipefail

source "$(dirname "$0")/base-test.sh"

finalizer="$ROOT/bin/omarchy-apply-system"
config_dir="$ROOT/install/dinit/config"

bash -n "$finalizer" "$config_dir/all.sh" "$config_dir/snapper.sh" "$config_dir/firewall.sh" \
  "$ROOT/bin/omarchy-snapper-cleanup"

grep -F 'source "$OMARCHY_INSTALL/dinit/config/all.sh"' "$finalizer" >/dev/null ||
  fail "system finalizer enters the dinit-only configuration"
grep -F 'omarchy-snapper-cleanup' "$config_dir/snapper.sh" >/dev/null ||
  fail "dinit finalizer owns Snapper cleanup"
grep -F 'ISO bootstrap owns the package and its boot.d link' "$config_dir/firewall.sh" >/dev/null ||
  fail "dinit finalizer leaves UFW activation to the ISO bootstrap"
if rg -n '\bsystemctl\b|\bsystemd-run\b' "$finalizer" "$config_dir"; then
  fail "dinit finalizer does not invoke systemd"
fi

pass "system finalization is dinit-only"
