#!/bin/bash

# Configure Artix's official earlyoom-dinit service. Unlike systemd-oomd,
# earlyoom has no app.slice boundary, so root and session-critical processes
# are excluded while a runaway desktop application remains reclaimable.

set -euo pipefail

earlyoom_config="${OMARTIX_EARLYOOM_CONFIG:-/etc/dinit.d/config/earlyoom.conf}"
[[ -f $earlyoom_config ]] || {
  echo "Error: earlyoom configuration is unavailable: $earlyoom_config" >&2
  exit 1
}

policy='-m 8 -s 90 --ignore-root-user --avoid (^|/)(dinit|init|Hyprland|Xorg|Xwayland|sddm|greetd|tuigreet|elogind|dbus-daemon)$ --prefer (^|/)(firefox|zen|chromium|chrome|electron|code|java|node)$ -r 3600'

# An active value is an administrator's explicit memory-pressure policy.
grep -qE '^EARLYOOM_ARGS=' "$earlyoom_config" && exit 0

if grep -qE '^#EARLYOOM_ARGS=' "$earlyoom_config"; then
  sed -i -E "s@^#EARLYOOM_ARGS=.*@EARLYOOM_ARGS=\"${policy}\"@" "$earlyoom_config"
else
  printf 'EARLYOOM_ARGS="%s"\n' "$policy" >>"$earlyoom_config"
fi
