#!/bin/bash

echo "Supervise fcitx5 so CapsLock compose sequences can't silently die"

# fcitx5 was launched fire-and-forget from Hyprland's autostart. Nothing
# restarted it and nothing noticed when it went away, so a single lost start
# left every ~/.XCompose sequence (CapsLock m s -> emoji) dead for the rest of
# the session. Omartix owns that process through a dinit user service instead.

source_service="$OMARCHY_PATH/install/artix/dinit/user/omarchy-fcitx5"
service_dir="${XDG_CONFIG_HOME:-$HOME/.config}/dinit.d"
service="$service_dir/omarchy-fcitx5"
legacy_wants="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/graphical-session.target.wants/omarchy-fcitx5.service"

if [[ ! -f $source_service ]]; then
  echo "Omartix dinit service definition is missing: $source_service" >&2
  exit 1
fi

install -Dm644 "$source_service" "$service"

# This link was written by the systemd version of the migration. Remove only
# that managed entry; users may still have an unrelated systemd configuration.
rm -f -- "$legacy_wants"

# An update over SSH or a TTY must not start an input method against a missing
# Wayland socket. The next graphical login invokes omarchy-session-init. In an
# existing graphical session, replace the old unsupervised process and report a
# failed handover instead of silently leaving compose input unavailable.
if [[ -n ${WAYLAND_DISPLAY:-} ]] && dinitctl --user list >/dev/null 2>&1; then
  pkill -x fcitx5 >/dev/null 2>&1 || true

  if ! error=$(dinitctl --user restart omarchy-fcitx5 2>&1); then
    echo "Could not restart omarchy-fcitx5: $error"
    echo "Compose sequences (CapsLock m s) will not work until the next login."
  fi
fi
