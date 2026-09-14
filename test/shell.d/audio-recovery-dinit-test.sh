#!/bin/bash

set -euo pipefail

source "$(dirname "$0")/base-test.sh"

for command in "$ROOT/bin/omarchy-restart-audio" "$ROOT/bin/omarchy-restart-xcompose"; do
  bash -n "$command"
  if rg -n '\bsystemctl\b|\bsystemd-run\b' "$command"; then
    fail "$(basename "$command") has no systemd fallback"
  fi
done

rg -F 'dinitctl --user restart' "$ROOT/bin/omarchy-restart-audio" >/dev/null ||
  fail "audio recovery restarts dinit user services"
rg -F 'dinitctl --user stop omarchy-fcitx5' "$ROOT/bin/omarchy-restart-xcompose" >/dev/null ||
  fail "XCompose stops dinit fcitx5 service"
rg -F 'command = /usr/bin/fcitx5 --disable notificationitem' "$ROOT/install/dinit/user/omarchy-fcitx5" >/dev/null ||
  fail "fcitx5 dinit service has the expected command"

pass "audio and XCompose recovery use dinit user services"
