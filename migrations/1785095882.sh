#!/bin/bash

echo "Only check for pending migrations at login, not on every package update"

# Keep the once-per-login notifier, but run it through dinit. Do not start it
# from this migration: omarchy-update runs migrations itself, so an immediate
# start would announce work that is already being applied in the visible update
# terminal. omarchy-session-init starts it at the next graphical login.
user_config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
source_service="$OMARCHY_PATH/install/artix/dinit/user/omarchy-migrate-notify"
service="$user_config_home/dinit.d/omarchy-migrate-notify"
wants_dir="$user_config_home/systemd/user/graphical-session.target.wants"

if [[ ! -f $source_service ]]; then
  echo "Omartix dinit service definition is missing: $source_service" >&2
  exit 1
fi

install -Dm644 "$source_service" "$service"
rm -f -- "$wants_dir/omarchy-update-user-notify.path" \
  "$wants_dir/omarchy-update-user-notify.service" \
  "$wants_dir/omarchy-migrate-notify.service"
