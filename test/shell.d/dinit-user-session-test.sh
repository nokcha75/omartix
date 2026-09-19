#!/bin/bash

set -euo pipefail

source "$(dirname "$0")/base-test.sh"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/bin"
cat >"$tmpdir/bin/dinitctl" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >>"$OMARCHY_SESSION_LOG"
[[ $2 == list ]] && exit 0
exit 0
EOF
cat >"$tmpdir/bin/dbus-update-activation-environment" <<'EOF'
#!/bin/bash
printf 'dbus %s\n' "$*" >>"$OMARCHY_SESSION_LOG"
EOF
cat >"$tmpdir/bin/pgrep" <<'EOF'
#!/bin/bash
[[ $* == *bluetoothd ]] && exit 0
exit 1
EOF
chmod +x "$tmpdir/bin/"*

service_dir="$tmpdir/config/dinit.d"
mkdir -p "$service_dir"
for service in omarchy-fcitx5 omarchy-sleep-lock omarchy-migrate-notify omarchy-crash-watch omarchy-recover-internal-monitor bt-agent; do
  : >"$service_dir/$service"
done
mkdir -p "$tmpdir/home/.local/state/omarchy/toggles/hypr" "$tmpdir/sys/class/bluetooth"
touch "$tmpdir/home/.local/state/omarchy/toggles/hypr/internal-monitor-disable.lua"

log="$tmpdir/dinit.log"
HOME="$tmpdir/home" XDG_CONFIG_HOME="$tmpdir/config" WAYLAND_DISPLAY=wayland-1 \
  OMARCHY_SESSION_TEST=artix OMARCHY_SESSION_LOG="$log" OMARCHY_BLUETOOTH_PATH="$tmpdir/sys/class/bluetooth" \
  PATH="$tmpdir/bin:$PATH" "$ROOT/bin/omarchy-session-init"

grep -Fx -- '--user setenv OMARCHY_SESSION_TEST=artix' "$log" >/dev/null ||
  fail "dinit receives the Hyprland environment"
grep -Fx -- 'dbus --all' "$log" >/dev/null ||
  fail "session updates D-Bus activation without systemd"
for service in omarchy-fcitx5 omarchy-sleep-lock omarchy-migrate-notify omarchy-crash-watch omarchy-recover-internal-monitor bt-agent; do
  grep -Fx -- "--user start $service" "$log" >/dev/null ||
    fail "session starts $service after importing its environment"
done
if grep -F systemctl "$log" >/dev/null; then
  fail "session initialization does not invoke systemctl"
fi
pass "Hyprland session starts Omartix dinit user services"

for service in bt-agent omarchy-fcitx5 omarchy-sleep-lock omarchy-recover-internal-monitor omarchy-migrate-notify omarchy-crash-watch; do
  [[ -f "$ROOT/install/artix/dinit/user/$service" ]] || fail "dinit service definition exists for $service"
done
if rg -n '\bsystemctl\b|\bsystemd-run\b' \
  "$ROOT/bin/omarchy-session-init" \
  "$ROOT/install/user/first-run/enable-user-units.sh" \
  "$ROOT/install/artix/dinit/user" \
  "$ROOT/default/hypr/autostart.lua"; then
  fail "Hyprland user-session path has no systemd dependency"
fi
pass "Hyprland user-session path is dinit-only"
