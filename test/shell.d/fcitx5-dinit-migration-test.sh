#!/bin/bash

set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "$0")/base-test.sh"

migration="$ROOT/migrations/1785167800.sh"
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT

stub_bin="$test_dir/bin"
mkdir -p "$stub_bin"

cat >"$stub_bin/dinitctl" <<'STUB'
#!/bin/bash

printf '%s\n' "$*" >>"$DINIT_CALLS"
[[ ${1:-} == --user && ${2:-} == list ]] && exit "${DINIT_LIST_STATUS:-0}"
exit "${DINIT_RESTART_STATUS:-0}"
STUB

cat >"$stub_bin/pkill" <<'STUB'
#!/bin/bash

printf '%s\n' "$*" >>"$PKILL_CALLS"
STUB

chmod +x "$stub_bin/dinitctl" "$stub_bin/pkill"

run_migration() {
  local home="$1"
  local wayland_display="${2:-}"

  : >"$DINIT_CALLS"
  : >"$PKILL_CALLS"
  HOME="$home" XDG_CONFIG_HOME="$home/.config" OMARCHY_PATH="$ROOT" \
    WAYLAND_DISPLAY="$wayland_display" DINIT_CALLS="$DINIT_CALLS" PKILL_CALLS="$PKILL_CALLS" \
    PATH="$stub_bin:$PATH" bash -euo pipefail "$migration"
}

DINIT_CALLS="$test_dir/dinit-calls"
PKILL_CALLS="$test_dir/pkill-calls"

tty_home="$test_dir/tty-home"
legacy_link="$tty_home/.config/systemd/user/graphical-session.target.wants/omarchy-fcitx5.service"
mkdir -p "$(dirname "$legacy_link")"
ln -s /usr/lib/systemd/user/omarchy-fcitx5.service "$legacy_link"

run_migration "$tty_home"

cmp "$ROOT/install/artix/dinit/user/omarchy-fcitx5" "$tty_home/.config/dinit.d/omarchy-fcitx5" >/dev/null ||
  fail "fcitx5 migration installs the dinit user-service definition"
pass "fcitx5 migration installs the dinit user-service definition"

[[ ! -e $legacy_link && ! -L $legacy_link ]] ||
  fail "fcitx5 migration removes only its legacy systemd enablement link"
pass "fcitx5 migration removes its legacy systemd enablement link"

[[ ! -s $DINIT_CALLS && ! -s $PKILL_CALLS ]] ||
  fail "fcitx5 migration does not start input services from a TTY" "$(cat "$DINIT_CALLS" "$PKILL_CALLS")"
pass "fcitx5 migration leaves input services stopped outside Wayland"

wayland_home="$test_dir/wayland-home"
run_migration "$wayland_home" wayland-1

grep -qxF -- '--user list' "$DINIT_CALLS" ||
  fail "fcitx5 migration checks for a dinit user manager before handover" "$(cat "$DINIT_CALLS")"
grep -qxF -- '--user restart omarchy-fcitx5' "$DINIT_CALLS" ||
  fail "fcitx5 migration restarts the supervised service in Wayland" "$(cat "$DINIT_CALLS")"
grep -qxF -- '-x fcitx5' "$PKILL_CALLS" ||
  fail "fcitx5 migration removes the old unsupervised process before handover" "$(cat "$PKILL_CALLS")"
pass "fcitx5 migration hands an existing Wayland session to dinit"

DINIT_LIST_STATUS=1 run_migration "$test_dir/no-manager-home" wayland-1
[[ $(<"$DINIT_CALLS") == "--user list" ]] ||
  fail "fcitx5 migration defers handover when no dinit user manager exists" "$(cat "$DINIT_CALLS")"
[[ ! -s $PKILL_CALLS ]] ||
  fail "fcitx5 migration keeps the active input method when handover is unavailable" "$(cat "$PKILL_CALLS")"
pass "fcitx5 migration defers safely without a dinit user manager"
