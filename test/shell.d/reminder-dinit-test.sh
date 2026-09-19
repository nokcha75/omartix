#!/bin/bash

set -euo pipefail

source "$(dirname "$0")/base-test.sh"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/bin" "$tmpdir/home"

cat >"$tmpdir/bin/date" <<'EOF'
#!/bin/bash
case "$*" in
  '+%s') echo 1000 ;;
  '-d +5 minutes +%H:%M') echo 12:05 ;;
  *) /usr/bin/date "$@" ;;
esac
EOF
cat >"$tmpdir/bin/dinitctl" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >>"$OMARCHY_REMINDER_LOG"
EOF
cat >"$tmpdir/bin/omarchy-cmd-missing" <<'EOF'
#!/bin/bash
exit 1
EOF
cat >"$tmpdir/bin/omarchy-notification-send" <<'EOF'
#!/bin/bash
printf 'notify %s\n' "$*" >>"$OMARCHY_REMINDER_LOG"
EOF
cat >"$tmpdir/bin/omarchy-shell" <<'EOF'
#!/bin/bash
printf 'shell %s\n' "$*" >>"$OMARCHY_REMINDER_LOG"
EOF
chmod +x "$tmpdir/bin/"*

log="$tmpdir/reminder.log"
HOME="$tmpdir/home" XDG_STATE_HOME="$tmpdir/state" OMARCHY_REMINDER_LOG="$log" PATH="$tmpdir/bin:$PATH" \
  "$ROOT/bin/omarchy-reminder" 5 'Check the oven'

unit=omarchy-reminder-5m-1000
service="$tmpdir/home/.config/dinit.d/$unit"
meta="$tmpdir/state/omarchy/reminders/$unit.meta"
message="$tmpdir/state/omarchy/reminders/$unit.message"

[[ $(<"$meta") == 1300 ]] || fail "reminder records its due epoch"
[[ $(<"$message") == 'Check the oven' ]] || fail "reminder preserves its message"
grep -Fx "command = /usr/bin/omarchy-reminder-worker $unit" "$service" >/dev/null ||
  fail "reminder service invokes the dinit worker"
grep -Fx -- "--user start $unit" "$log" >/dev/null || fail "reminder starts a dinit user service"
if rg -q '\bsystemctl\b|\bsystemd-run\b' "$ROOT/bin/omarchy-reminder"; then
  fail "reminder has no systemd fallback"
fi
pass "dinit reminder creates and starts a one-shot user service"

HOME="$tmpdir/home" XDG_STATE_HOME="$tmpdir/state" OMARCHY_REMINDER_LOG="$log" PATH="$tmpdir/bin:$PATH" \
  "$ROOT/bin/omarchy-reminder" clear
[[ ! -e $service && ! -e $meta && ! -e $message ]] || fail "clear removes dinit reminder state"
grep -Fx -- "--user stop $unit" "$log" >/dev/null || fail "clear stops the dinit user service"
pass "dinit reminder clear removes the user service and state"
