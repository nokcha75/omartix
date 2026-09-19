#!/bin/bash

set -euo pipefail

echo "Ensure NetworkManager is managed by dinit"

as_root() {
  if (( EUID == 0 )); then
    "$@"
  else
    sudo "$@"
  fi
}

# Omartix is installed on Artix with dinit from the outset. Install the Artix
# service definition and make NetworkManager persistent without stopping a
# live connection or touching legacy network-manager state.
if ! error=$(omarchy-pkg-add networkmanager networkmanager-dinit 2>&1); then
  echo "Could not install Artix NetworkManager packages: $error"
  echo "The network migration will be retried by omarchy-migrate."
  exit 1
fi

if ! error=$(as_root dinitctl enable NetworkManager 2>&1); then
  echo "Could not enable the NetworkManager dinit service: $error"
  echo "The network migration will be retried by omarchy-migrate."
  exit 1
fi

# Start is idempotent. It brings a migrated install under NetworkManager now;
# unlike the old cutover it never tears down another active network manager.
if ! error=$(as_root dinitctl start NetworkManager 2>&1); then
  echo "Could not start the NetworkManager dinit service: $error"
  echo "The network migration will be retried by omarchy-migrate."
  exit 1
fi
