#!/bin/bash

echo "Stop the migration notifier from re-triggering itself in a loop"

# The old notifier was a systemd path unit and could retrigger itself while an
# update wrote the migrations directory. Omartix checks once per graphical
# login through a dinit user service, so the path watcher is retired entirely.
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
