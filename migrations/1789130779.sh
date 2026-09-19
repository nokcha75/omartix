#!/bin/bash

set -euo pipefail

echo "Keep the KEF LSX II LT USB sink from suspending"

conf="wireplumber/wireplumber.conf.d/kef-lsx-no-suspend.conf"

if [[ ! -f "$HOME/.config/$conf" ]]; then
  omarchy-refresh-config "$conf"
  # WirePlumber only reads conf.d at startup. Preserve try-restart semantics:
  # do not create audio services during an SSH or TTY update, but apply the
  # change immediately in an existing dinit-managed graphical session.
  if dinitctl --user is-started wireplumber >/dev/null 2>&1; then
    dinitctl --user restart wireplumber >/dev/null 2>&1 || true
  fi
fi
