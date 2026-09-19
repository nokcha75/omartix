#!/bin/bash

set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "$0")/base-test.sh"

test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT

first_migration="$ROOT/migrations/1784521870.sh"
second_migration="$ROOT/migrations/1785095882.sh"
home="$test_dir/home"
config="$home/.config"
wants_dir="$config/systemd/user/graphical-session.target.wants"
service="$config/dinit.d/omarchy-migrate-notify"

mkdir -p "$wants_dir"
for legacy in omarchy-update-user-notify.path omarchy-update-user-notify.service omarchy-migrate-notify.service; do
  ln -s "/usr/lib/systemd/user/$legacy" "$wants_dir/$legacy"
done

run_migration() {
  HOME="$home" XDG_CONFIG_HOME="$config" OMARCHY_PATH="$ROOT" \
    PATH="/usr/bin:/bin" bash -euo pipefail "$1"
}

run_migration "$first_migration"

cmp "$ROOT/install/artix/dinit/user/omarchy-migrate-notify" "$service" >/dev/null ||
  fail "the first notifier migration installs the dinit service definition"
pass "the first notifier migration installs the dinit service definition"

for legacy in omarchy-update-user-notify.path omarchy-update-user-notify.service omarchy-migrate-notify.service; do
  [[ ! -e $wants_dir/$legacy && ! -L $wants_dir/$legacy ]] ||
    fail "the first notifier migration removes legacy systemd enablement" "$legacy"
done
pass "the first notifier migration removes legacy systemd enablement"

run_migration "$second_migration"

cmp "$ROOT/install/artix/dinit/user/omarchy-migrate-notify" "$service" >/dev/null ||
  fail "the later notifier migration keeps the dinit service definition current"
pass "the later notifier migration keeps the dinit service definition current"

if rg -n '\b(systemctl|dinitctl)\b' "$first_migration" "$second_migration" >/dev/null; then
  fail "notifier migrations do not start or manage services during omarchy-update"
fi
pass "notifier migrations defer service start until graphical login"
