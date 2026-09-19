#!/bin/bash

set -euo pipefail

echo "Restart NetworkManager when Wi-Fi is unavailable"

# Artix's NetworkManager depends on wpa_supplicant directly and activates it
# over D-Bus; there is no separate dinit service or legacy mask to repair.
# NetworkManager stops retrying after repeated failures, so restart it only
# when it is already active and nmcli reports an unavailable Wi-Fi device.
if dinitctl is-started NetworkManager >/dev/null 2>&1 &&
  [[ $(LC_ALL=C nmcli -t -f TYPE,STATE device 2>/dev/null || true) == *"wifi:unavailable"* ]]; then
  sudo dinitctl restart NetworkManager >/dev/null 2>&1 || true
fi
