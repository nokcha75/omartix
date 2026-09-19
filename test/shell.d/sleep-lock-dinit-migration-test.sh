#!/bin/bash

set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "$0")/base-test.sh"

migration="$ROOT/migrations/1785608166.sh"
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT

stub_bin="$test_dir/bin"
mkdir -p "$stub_bin"

cat >"$stub_bin/dinitctl" <<'STUB'
#!/bin/bash

printf '%s\n' "$*" >>"$DINIT_CALLS"
[[ ${1:-} == --user && ${2:-} == list ]] && exit "${DINIT_LIST_STATUS:-0}"
[[ ${1:-} == --user && ${2:-} == start ]] && exit "${DINIT_START_STATUS:-0}"
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
legacy_dir="$tty_home/.config/systemd/user/omarchy-sleep-lock.service.d"
legacy_dropin="$legacy_dir/90-omarchy-session-environment.conf"
legacy_link="$tty_home/.config/systemd/user/graphical-session.target.wants/omarchy-sleep-lock.service"
custom_unit="$tty_home/.config/systemd/user/omarchy-sleep-lock.service"
mkdir -p "$legacy_dir" "$(dirname "$legacy_link")"
printf 'old managed drop-in\n' >"$legacy_dropin"
printf 'user customization\n' >"$custom_unit"
ln -s /usr/lib/systemd/user/omarchy-sleep-lock.service "$legacy_link"

run_migration "$tty_home"

cmp "$ROOT/install/artix/dinit/user/omarchy-sleep-lock" "$tty_home/.config/dinit.d/omarchy-sleep-lock" >/dev/null ||
  fail "sleep-lock migration installs the dinit user-service definition"
pass "sleep-lock migration installs the dinit user-service definition"

[[ ! -e $legacy_link && ! -L $legacy_link && ! -e $legacy_dropin ]] ||
  fail "sleep-lock migration removes managed systemd enablement and drop-in"
pass "sleep-lock migration removes managed systemd state"

[[ $(<"$custom_unit") == "user customization" ]] ||
  fail "sleep-lock migration preserves a user-written legacy unit"
pass "sleep-lock migration preserves user customization"

[[ ! -s $DINIT_CALLS ]] ||
  fail "sleep-lock migration does not start a monitor from a TTY" "$(cat "$DINIT_CALLS")"
pass "sleep-lock migration leaves a headless session unchanged"

wayland_home="$test_dir/wayland-home"
run_migration "$wayland_home" wayland-1

grep -qxF -- '--user list' "$DINIT_CALLS" ||
  fail "sleep-lock migration checks for a dinit user manager" "$(cat "$DINIT_CALLS")"
grep -qxF -- '--user stop omarchy-sleep-lock' "$DINIT_CALLS" ||
  fail "sleep-lock migration stops a stale monitor before handover" "$(cat "$DINIT_CALLS")"
grep -qxF -- '--user start omarchy-sleep-lock' "$DINIT_CALLS" ||
  fail "sleep-lock migration starts the dinit monitor in Wayland" "$(cat "$DINIT_CALLS")"
pass "sleep-lock migration hands a Wayland session to dinit"

if DINIT_START_STATUS=1 run_migration "$test_dir/failed-start-home" wayland-1 >/dev/null 2>&1; then
  fail "sleep-lock migration stays pending when the live handover fails"
fi
pass "sleep-lock migration stays pending when the live handover fails"
