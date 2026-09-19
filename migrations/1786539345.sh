#!/bin/bash

echo "Announce process crashes and offer an AI diagnosis"

# Both halves are set up in paths that only run once -- omarchy-provision-user
# exits after finalize-user is marked, and install/user/first-run is skipped
# after the first login -- so existing installs need them done here.

skills_source="$OMARCHY_PATH/default/agents/skills"

if [[ -d $skills_source/diagnose-crash ]]; then
  for skills_dir in ~/.agents/skills ~/.claude/skills ~/.codex/skills ~/.pi/agent/skills; do
    mkdir -p "$skills_dir"
    ln -sfn "$skills_source/diagnose-crash" "$skills_dir/diagnose-crash"
  done
fi

user_config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
source_service="$OMARCHY_PATH/install/artix/dinit/user/omarchy-crash-watch"
service="$user_config_home/dinit.d/omarchy-crash-watch"
legacy_wants="$user_config_home/systemd/user/graphical-session.target.wants/omarchy-crash-watch.service"
disabled_flag="$HOME/.local/state/omarchy/toggles/crash-capture-off"

if [[ ! -f $source_service ]]; then
  echo "Omartix dinit service definition is missing: $source_service" >&2
  exit 1
fi

install -Dm644 "$source_service" "$service"
rm -f -- "$legacy_wants"

# Nothing should start into over SSH or a TTY; the next graphical login runs
# omarchy-session-init. Respect a user's crash-capture opt-out during a live
# handover as well, so migrations never turn the feature back on.
if [[ ! -e $disabled_flag && -n ${WAYLAND_DISPLAY:-} ]] && dinitctl --user list >/dev/null 2>&1; then
  dinitctl --user start omarchy-crash-watch >/dev/null 2>&1 || true
fi
