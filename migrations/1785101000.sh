#!/bin/bash

echo "Save incoming Taildrop files to ~/Downloads"

# Taildrop is optional. A machine that never installed Tailscale must not pull
# it in during an unrelated update. For an existing installation, transition
# both the daemon and the per-user receiver to the dinit services Omartix uses.
if ! omarchy-cmd-present tailscale; then
  exit 0
fi

if ! error=$(omarchy-pkg-add tailscale-dinit 2>&1); then
  echo "Could not install tailscale-dinit: $error"
  echo "The Taildrop receiver migration will be retried by omarchy-migrate."
  exit 1
fi

if ! error=$(sudo dinitctl enable tailscaled 2>&1) ||
  ! error=$(sudo dinitctl start tailscaled 2>&1); then
  echo "Could not enable the tailscaled dinit service: $error"
  echo "The Taildrop receiver migration will be retried by omarchy-migrate."
  exit 1
fi

user_config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
source_service="$OMARCHY_PATH/install/artix/dinit/user/omarchy-tailscale-receive"
service_dir="$user_config_home/dinit.d"
service="$service_dir/omarchy-tailscale-receive"
boot_link="$service_dir/boot.d/omarchy-tailscale-receive"
legacy_wants="$user_config_home/systemd/user/graphical-session.target.wants/omarchy-tailscale-receive.service"

if [[ ! -f $source_service ]]; then
  echo "Omartix dinit service definition is missing: $source_service" >&2
  exit 1
fi

install -Dm644 "$source_service" "$service"
install -d "$service_dir/boot.d"
ln -sfn ../omarchy-tailscale-receive "$boot_link"
rm -f -- "$legacy_wants"

# A user manager is not guaranteed during an SSH update. boot.d starts the
# receiver as soon as that user's dinit manager exists, so failing to reach it
# now is not a migration failure.
if dinitctl --user list >/dev/null 2>&1; then
  if ! error=$(dinitctl --user start omarchy-tailscale-receive 2>&1); then
    echo "Could not start omarchy-tailscale-receive: $error"
    echo "The Taildrop receiver will start on the next login."
  fi
fi
