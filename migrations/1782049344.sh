#!/bin/bash

set -euo pipefail

echo "Disable Limine Snapper warning notifier"

autostart_file="$HOME/.config/autostart/limine-snapper-notify.desktop"

mkdir -p "$(dirname "$autostart_file")"
cat >"$autostart_file" <<'DESKTOP'
[Desktop Entry]
Hidden=true
DESKTOP
