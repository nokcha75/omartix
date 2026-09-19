#!/bin/bash

echo "Tune reclaim for swap on zram"

# Everything here only applies the shipped config early; boot picks it up
# regardless. Nothing is worth failing the migration chain over, so each step
# falls back to asking for a reboot.

# Load our file specifically rather than --system, which returns nonzero for
# any invalid key in any admin sysctl file on the machine.
sudo sysctl -p /etc/sysctl.d/99-omarchy-sysctl.conf >/dev/null || true

if ! error=$(omarchy-pkg-add zramen zramen-dinit 2>&1); then
  echo "Could not install the Artix zram dinit packages: $error"
  echo "The zram migration will be retried by omarchy-migrate."
  exit 1
fi

if ! error=$(sudo "$OMARCHY_PATH/install/dinit/config/zram.sh" 2>&1); then
  echo "Could not configure zramen: $error"
  echo "The zram migration will be retried by omarchy-migrate."
  exit 1
fi

if ! error=$(sudo dinitctl enable zramen 2>&1); then
  echo "Could not enable the zramen dinit service: $error"
  echo "The zram migration will be retried by omarchy-migrate."
  exit 1
fi

# Resizing swaps the device off first, which faults every stored page back into
# memory. That is only cheap while all zram devices are empty. zramen may use a
# device other than zram0, so account for every active zram swap area.
swaps_file="${OMARTIX_PROC_SWAPS:-/proc/swaps}"
zram_used=$(awk '$1 ~ /^\/dev\/zram/ {sum += $4} END {print sum + 0}' "$swaps_file")

if [[ $zram_used == 0 ]] && sudo dinitctl restart zramen; then
  exit 0
fi

omarchy-state set reboot-required
