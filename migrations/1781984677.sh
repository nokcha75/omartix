#!/bin/bash

set -euo pipefail

echo "Normalize Snapper snapshot services"

OMARCHY_PATH="${OMARCHY_PATH:-/usr/share/omarchy}"
snapper_config_script=/usr/share/omarchy/install/dinit/config/snapper.sh
if [[ ! -f $snapper_config_script ]]; then
  snapper_config_script="$OMARCHY_PATH/install/dinit/config/snapper.sh"
fi

as_root() {
  if (( EUID == 0 )); then
    "$@"
  else
    sudo "$@"
  fi
}

if ! error=$(omarchy-pkg-add limine-snapper-sync limine-snapper-sync-dinit 2>&1); then
  echo "Could not install Artix Limine snapshot-sync packages: $error"
  echo "The Snapper migration will be retried by omarchy-migrate."
  exit 1
fi

if ! error=$(as_root env OMARCHY_PATH="$OMARCHY_PATH" bash -euo pipefail "$snapper_config_script" 2>&1); then
  echo "Could not configure Snapper: $error"
  echo "The Snapper migration will be retried by omarchy-migrate."
  exit 1
fi

for service in omarchy-snapper-cleanup limine-snapper-sync; do
  if ! error=$(as_root dinitctl enable "$service" 2>&1) ||
    ! error=$(as_root dinitctl start "$service" 2>&1); then
    echo "Could not enable $service through dinit: $error"
    echo "The Snapper migration will be retried by omarchy-migrate."
    exit 1
  fi
done
