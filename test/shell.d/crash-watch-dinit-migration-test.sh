#!/bin/bash

set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "$0")/base-test.sh"

migration="$ROOT/migrations/1786539345.sh"
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT

stub_bin="$test_dir/bin"
mkdir -p "$stub_bin"

cat >"$stub_bin/dinitctl" <<'STUB'
#!/bin/bash

printf '%s\n' "$*" >>"$DINIT_CALLS"
[[ ${1:-} == --user && ${2:-} == list ]] && exit "${DINIT_LIST_STATUS:-0}"
exit 0
STUB

chmod +x "$stub_bin/dinitctl"

DINIT_CALLS="$test_dir/dinit-calls"

run_migration() {
  local home="$1"
  local wayland_display="${2:-}"

  : >"$DINIT_CALLS"
  HOME="$home" XDG_CONFIG_HOME="$home/.config" OMARCHY_PATH="$ROOT" \
    WAYLAND_DISPLAY="$wayland_display" DINIT_CALLS="$DINIT_CALLS" \
    PATH="$stub_bin:$PATH" bash -euo pipefail "$migration"
}

tty_home="$test_dir/tty-home"
legacy_link="$tty_home/.config/systemd/user/graphical-session.target.wants/omarchy-crash-watch.service"
mkdir -p "$(dirname "$legacy_link")"
ln -s /usr/lib/systemd/user/omarchy-crash-watch.service "$legacy_link"

run_migration "$tty_home"

cmp "$ROOT/install/artix/dinit/user/omarchy-crash-watch" "$tty_home/.config/dinit.d/omarchy-crash-watch" >/dev/null ||
  fail "crash-watch migration installs the dinit user-service definition"
pass "crash-watch migration installs the dinit user-service definition"
[[ ! -e $legacy_link && ! -L $legacy_link ]] ||
  fail "crash-watch migration removes its legacy systemd enablement link"
pass "crash-watch migration removes its legacy systemd enablement link"
[[ ! -s $DINIT_CALLS ]] ||
  fail "crash-watch migration does not start a watcher from a TTY" "$(cat "$DINIT_CALLS")"
pass "crash-watch migration leaves a headless session unchanged"

wayland_home="$test_dir/wayland-home"
run_migration "$wayland_home" wayland-1
grep -qxF -- '--user list' "$DINIT_CALLS" ||
  fail "crash-watch migration checks for a dinit user manager" "$(cat "$DINIT_CALLS")"
grep -qxF -- '--user start omarchy-crash-watch' "$DINIT_CALLS" ||
  fail "crash-watch migration starts the watcher in Wayland" "$(cat "$DINIT_CALLS")"
pass "crash-watch migration starts a live graphical watcher through dinit"

disabled_home="$test_dir/disabled-home"
mkdir -p "$disabled_home/.local/state/omarchy/toggles"
touch "$disabled_home/.local/state/omarchy/toggles/crash-capture-off"
run_migration "$disabled_home" wayland-1
[[ ! -s $DINIT_CALLS ]] ||
  fail "crash-watch migration preserves the user's disabled setting" "$(cat "$DINIT_CALLS")"
pass "crash-watch migration preserves the user's disabled setting"
