#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

dinit_dir="$ROOT/install/artix/dinit/user"
for service in bt-agent omarchy-crash-watch omarchy-fcitx5 omarchy-migrate-notify \
  omarchy-recover-internal-monitor omarchy-sleep-lock omarchy-tailscale-receive; do
  [[ -f $dinit_dir/$service ]] ||
    fail "Omartix ships the dinit replacement for $service"
done
pass "Omartix ships dinit replacements for every former user unit"

! rg --files "$ROOT/default/systemd/user" "$ROOT/default/systemd/user@.service.d" 2>/dev/null | grep -q . ||
  fail "Omartix no longer ships obsolete systemd user units"
[[ ! -f $ROOT/default/systemd/zram-generator.conf.d/90-omarchy.conf ]] ||
  fail "Omartix uses zramen instead of a systemd zram-generator drop-in"
[[ ! -f $ROOT/etc/systemd/oomd.conf.d/10-omarchy.conf ]] ||
  fail "Omartix uses earlyoom instead of systemd-oomd policy"
pass "Omartix does not ship replaced systemd user, zram, or oomd assets"

first_run="$ROOT/install/user/first-run/enable-user-units.sh"
grep -F 'install/artix/dinit/user' "$first_run" >/dev/null ||
  fail "first-run installs dinit user-service definitions"
grep -F 'omarchy-session-init' "$first_run" >/dev/null ||
  fail "first-run starts dinit services through the session initializer"
pass "first-run activates the dinit user-service set"
