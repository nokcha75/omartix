#!/bin/bash

echo "Let earlyoom protect the desktop from sustained memory exhaustion"

as_root() {
  if (( EUID == 0 )); then
    "$@"
  else
    sudo "$@"
  fi
}

if ! error=$(omarchy-pkg-add earlyoom earlyoom-dinit 2>&1); then
  echo "Could not install Artix earlyoom packages: $error"
  echo "The memory-pressure migration will be retried by omarchy-migrate."
  exit 1
fi

if ! error=$(as_root "$OMARCHY_PATH/install/dinit/config/earlyoom.sh" 2>&1); then
  echo "Could not configure earlyoom: $error"
  echo "The memory-pressure migration will be retried by omarchy-migrate."
  exit 1
fi

if ! error=$(as_root dinitctl enable earlyoom 2>&1); then
  echo "Could not enable earlyoom: $error"
  echo "The memory-pressure migration will be retried by omarchy-migrate."
  exit 1
fi

# Restarting applies the policy immediately. If it fails, boot.d enablement
# still applies it on the next boot, so the update remains usable.
as_root dinitctl restart earlyoom >/dev/null 2>&1 ||
  echo "earlyoom will start with Omartix policy after the next reboot."
