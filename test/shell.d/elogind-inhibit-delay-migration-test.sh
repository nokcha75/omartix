#!/bin/bash

set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "$0")/base-test.sh"

migration="$ROOT/migrations/1784970000.sh"
dropin=$(mktemp)
call_log=$(mktemp)
trap 'rm -f "$dropin" "$call_log"' EXIT

printf '[Login]\nInhibitDelayMaxSec=15\n' >"$dropin"

(
  # These functions are invoked indirectly by the sourced migration.
  # shellcheck disable=SC2329
  sudo() { "$@"; }
  # shellcheck disable=SC2329
  loginctl() { printf 'loginctl:%s\n' "$*" >>"$call_log"; }
  # shellcheck disable=SC2329
  busctl() { printf 't 15000000\n'; }
  # shellcheck disable=SC2329
  omarchy-state() { printf 'state:%s\n' "$*" >>"$call_log"; }

  OMARTIX_ELOGIND_INHIBIT_DROPIN="$dropin"
  export OMARTIX_ELOGIND_INHIBIT_DROPIN
  # shellcheck disable=SC1090
  source "$migration"
)

grep -Fx 'loginctl:daemon-reload' "$call_log" >/dev/null ||
  fail "inhibit-delay migration reloads elogind without restarting sessions"
if grep -F 'state:set reboot-required' "$call_log" >/dev/null; then
  fail "inhibit-delay migration accepts the effective elogind delay"
fi
pass "inhibit-delay migration verifies the elogind delay window"

elogind_dropin="$ROOT/etc/elogind/logind.conf.d/20-inhibit-delay.conf"
[[ -f $elogind_dropin ]] || fail "Omartix ships the elogind inhibit-delay drop-in"
if rg -n '\bsystemctl\b|/etc/systemd' "$migration" "$elogind_dropin" >/dev/null; then
  fail "inhibit-delay setup has no systemd service-manager path"
fi
pass "inhibit-delay setup is owned by elogind"
