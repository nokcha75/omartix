#!/bin/bash

set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "$0")/base-test.sh"

migration="$ROOT/migrations/1789130779.sh"
test_home=$(mktemp -d)
call_log=$(mktemp)
trap 'rm -rf "$test_home" "$call_log"' EXIT

(
  # These functions are invoked indirectly by the sourced migration.
  # shellcheck disable=SC2329
  omarchy-refresh-config() {
    mkdir -p "$HOME/.config/$(dirname "$1")"
    : >"$HOME/.config/$1"
    printf 'refresh:%s\n' "$1" >>"$call_log"
  }
  # shellcheck disable=SC2329
  dinitctl() {
    if [[ $1 == --user && $2 == is-started ]]; then
      return 0
    fi
    printf 'dinit:%s\n' "$*" >>"$call_log"
  }

  HOME="$test_home"
  export HOME
  # shellcheck disable=SC1090
  source "$migration"
)

grep -Fx 'refresh:wireplumber/wireplumber.conf.d/kef-lsx-no-suspend.conf' "$call_log" >/dev/null ||
  fail "WirePlumber migration installs the KEF policy"
grep -Fx 'dinit:--user restart wireplumber' "$call_log" >/dev/null ||
  fail "WirePlumber migration restarts the active dinit user service"
pass "WirePlumber migration applies policy through dinit"

if rg -n '\bsystemctl\b' "$migration" >/dev/null; then
  fail "WirePlumber migration has no systemd user-service path"
fi
pass "WirePlumber migration keeps session ownership in dinit"
