#!/bin/bash

echo "Repair the pre-suspend lock monitor's graphical session environment"

# The old systemd unit started before UWSM finished importing OMARCHY_PATH and
# WAYLAND_DISPLAY. Omartix starts the dinit service from omarchy-session-init,
# after the graphical environment has been imported, so no lifecycle drop-in is
# required. Preserve a user-written unit, but retire only the enablement and
# drop-in that Omarchy itself created.
user_config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
source_service="$OMARCHY_PATH/install/artix/dinit/user/omarchy-sleep-lock"
service="$user_config_home/dinit.d/omarchy-sleep-lock"
legacy_wants="$user_config_home/systemd/user/graphical-session.target.wants/omarchy-sleep-lock.service"
legacy_dropin_dir="$user_config_home/systemd/user/omarchy-sleep-lock.service.d"
legacy_dropin="$legacy_dropin_dir/90-omarchy-session-environment.conf"

if [[ ! -f $source_service ]]; then
  echo "Omartix dinit service definition is missing: $source_service" >&2
  exit 1
fi

install -Dm644 "$source_service" "$service"
rm -f -- "$legacy_wants" "$legacy_dropin"
rmdir --ignore-fail-on-non-empty "$legacy_dropin_dir" 2>/dev/null || true

# A headless update has no Wayland session to protect. The next graphical login
# invokes omarchy-session-init and starts the service with the right environment.
# In a live session, stop any old monitor before starting dinit's replacement;
# otherwise two monitors can race to lock the screen on suspend.
if [[ -n ${WAYLAND_DISPLAY:-} ]] && dinitctl --user list >/dev/null 2>&1; then
  dinitctl --user stop omarchy-sleep-lock >/dev/null 2>&1 || true

  if ! error=$(dinitctl --user start omarchy-sleep-lock 2>&1); then
    echo "Could not start omarchy-sleep-lock: $error"
    echo "The pre-suspend lock repair will be retried by omarchy-migrate."
    exit 1
  fi
fi
