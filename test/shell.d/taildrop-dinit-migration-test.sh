#!/bin/bash

set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "$0")/base-test.sh"

migration="$ROOT/migrations/1785101000.sh"
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT

stub_bin="$test_dir/bin"
mkdir -p "$stub_bin"

cat >"$stub_bin/omarchy-cmd-present" <<'STUB'
#!/bin/bash
[[ ${TAILSCALE_PRESENT:-0} == 1 ]]
STUB

cat >"$stub_bin/omarchy-pkg-add" <<'STUB'
#!/bin/bash
printf '%s\n' "$*" >>"$PACKAGE_CALLS"
exit "${PACKAGE_STATUS:-0}"
STUB

cat >"$stub_bin/sudo" <<'STUB'
#!/bin/bash
"$@"
STUB

cat >"$stub_bin/dinitctl" <<'STUB'
#!/bin/bash
printf '%s\n' "$*" >>"$DINIT_CALLS"
[[ ${1:-} == --user && ${2:-} == list ]] && exit "${DINIT_LIST_STATUS:-0}"
[[ ${1:-} == --user && ${2:-} == start && ${DINIT_USER_START_STATUS:-0} != 0 ]] && exit "$DINIT_USER_START_STATUS"
exit "${DINIT_SYSTEM_STATUS:-0}"
STUB

chmod +x "$stub_bin"/*

PACKAGE_CALLS="$test_dir/package-calls"
DINIT_CALLS="$test_dir/dinit-calls"

run_migration() {
  local home="$1"
  : >"$PACKAGE_CALLS"
  : >"$DINIT_CALLS"
  HOME="$home" XDG_CONFIG_HOME="$home/.config" OMARCHY_PATH="$ROOT" \
    TAILSCALE_PRESENT="${2:-1}" PACKAGE_CALLS="$PACKAGE_CALLS" DINIT_CALLS="$DINIT_CALLS" \
    PATH="$stub_bin:$PATH" bash -euo pipefail "$migration"
}

run_migration "$test_dir/no-tailscale-home" 0
[[ ! -s $PACKAGE_CALLS && ! -s $DINIT_CALLS ]] ||
  fail "Taildrop migration leaves machines without Tailscale unchanged"
pass "Taildrop migration leaves machines without Tailscale unchanged"

home="$test_dir/tailscale-home"
legacy_link="$home/.config/systemd/user/graphical-session.target.wants/omarchy-tailscale-receive.service"
mkdir -p "$(dirname "$legacy_link")"
ln -s /usr/lib/systemd/user/omarchy-tailscale-receive.service "$legacy_link"
run_migration "$home"

grep -qxF tailscale-dinit "$PACKAGE_CALLS" ||
  fail "Taildrop migration installs the remote Artix dinit companion package" "$(cat "$PACKAGE_CALLS")"
grep -qxF 'enable tailscaled' "$DINIT_CALLS" ||
  fail "Taildrop migration enables tailscaled through dinit" "$(cat "$DINIT_CALLS")"
grep -qxF 'start tailscaled' "$DINIT_CALLS" ||
  fail "Taildrop migration starts tailscaled through dinit" "$(cat "$DINIT_CALLS")"
cmp "$ROOT/install/artix/dinit/user/omarchy-tailscale-receive" "$home/.config/dinit.d/omarchy-tailscale-receive" >/dev/null ||
  fail "Taildrop migration installs the dinit receiver definition"
[[ -L $home/.config/dinit.d/boot.d/omarchy-tailscale-receive ]] ||
  fail "Taildrop migration persistently enables the receiver for dinit"
[[ ! -e $legacy_link && ! -L $legacy_link ]] ||
  fail "Taildrop migration removes its legacy systemd enablement link"
pass "Taildrop migration transitions installed Tailscale to dinit"

grep -qxF -- '--user list' "$DINIT_CALLS" ||
  fail "Taildrop migration checks whether a user dinit manager is available" "$(cat "$DINIT_CALLS")"
grep -qxF -- '--user start omarchy-tailscale-receive' "$DINIT_CALLS" ||
  fail "Taildrop migration starts the receiver in an available user manager" "$(cat "$DINIT_CALLS")"
pass "Taildrop migration starts the receiver when its user manager is available"

DINIT_SYSTEM_STATUS=1 run_migration "$test_dir/failed-daemon-home" >/dev/null 2>&1 &&
  fail "Taildrop migration stays pending when tailscaled cannot be enabled"
pass "Taildrop migration stays pending when tailscaled cannot be enabled"
