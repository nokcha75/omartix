#!/bin/bash

source "$(dirname "$0")/base-test.sh"

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

mock_bin="$test_tmp/bin"
call_log="$test_tmp/calls.log"
mkdir -p "$mock_bin"

cat >"$mock_bin/nohup" <<'SH'
#!/bin/bash

printf 'nohup %s\n' "$*" >>"$CALL_LOG"
[[ ${FAIL_NOHUP:-false} == "true" ]] && exit 1
exit 0
SH

for command in omarchy-osd omarchy-state omarchy-hyprland-window-close-all sleep; do
  cat >"$mock_bin/$command" <<'SH'
#!/bin/bash

printf '%s %s\n' "$(basename "$0")" "$*" >>"$CALL_LOG"
SH
done
chmod +x "$mock_bin"/*

run_power_command() {
  local action="$1"

  : >"$call_log"
  PATH="$mock_bin:$PATH" CALL_LOG="$call_log" "$ROOT/bin/omarchy-system-$action"
}

assert_power_calls() {
  local action="$1"
  local loginctl_action="$2"

  grep -Fx "nohup /usr/bin/sh -c sleep 2; exec /usr/bin/loginctl $loginctl_action" "$call_log" >/dev/null ||
    fail "$action schedules elogind outside the terminal"
  grep -Fx 'omarchy-state clear re*-required' "$call_log" >/dev/null ||
    fail "$action clears pending restart state"
  grep -Fx 'omarchy-hyprland-window-close-all ' "$call_log" >/dev/null ||
    fail "$action closes application windows"
  grep -Fx 'sleep 1' "$call_log" >/dev/null ||
    fail "$action leaves applications a short shutdown grace period"
  pass "$action runs after being scheduled outside the terminal"
}

run_power_command reboot
assert_power_calls reboot reboot

run_power_command shutdown
assert_power_calls shutdown poweroff

for action in suspend hibernate; do
  grep -Fx "exec /usr/bin/loginctl $action" "$ROOT/bin/omarchy-system-$action" >/dev/null ||
    fail "$action delegates to elogind"
done
pass "suspend and hibernate delegate to elogind"

menu="$ROOT/default/omarchy/omarchy-menu.jsonc"
grep -F '"action":"omarchy-system-suspend"' "$menu" >/dev/null ||
  fail "menu suspend action uses Omartix wrapper"
grep -F '"action":"omarchy-system-hibernate"' "$menu" >/dev/null ||
  fail "menu hibernate action uses Omartix wrapper"
pass "power menu preserves the Omarchy commands through dinit wrappers"
