#!/bin/bash

# Install the Omartix dinit user-service definitions after the graphical
# session exists. They are started by omarchy-session-init only after it has
# imported Hyprland's environment, so they never inherit a headless login.

set -euo pipefail

source_dir="$OMARCHY_PATH/install/artix/dinit/user"
target_dir="${XDG_CONFIG_HOME:-$HOME/.config}/dinit.d"

[[ -d $source_dir ]] || {
  echo "Omartix dinit user-service definitions are missing" >&2
  exit 1
}

install -d "$target_dir"
for service in "$source_dir"/*; do
  [[ -f $service ]] || continue
  install -Dm644 "$service" "$target_dir/$(basename "$service")"
done

omarchy-session-init
