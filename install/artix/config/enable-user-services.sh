#!/bin/bash

# Enable graphical Omartix helpers for userspawn/dinit after the session exists.

set -euo pipefail

user_service_dir="$HOME/.config/dinit.d"
boot_dir="$user_service_dir/boot.d"
source_dir="$OMARCHY_PATH/install/artix/dinit/user"

[[ -d $source_dir ]] || {
  echo "Omartix dinit user service directory is missing: $source_dir" >&2
  exit 1
}

mkdir -p "$boot_dir"
for service in "$source_dir"/*; do
  [[ -f $service ]] || continue
  name=$(basename "$service")
  install -Dm644 "$service" "$user_service_dir/$name"
  ln -sfn "../$name" "$boot_dir/$name"
done

for service in omarchy-fcitx5 omarchy-sleep-lock; do
  dinitctl --user start "$service"
done

if [[ -d /sys/class/bluetooth ]] && dinitctl is-started bluetoothd >/dev/null 2>&1; then
  dinitctl --user start bt-agent || true
fi
