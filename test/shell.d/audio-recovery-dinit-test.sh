#!/bin/bash

set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "$0")/base-test.sh"

audio="$ROOT/bin/omarchy-restart-audio"
xcompose="$ROOT/bin/omarchy-restart-xcompose"
fcitx_service="$ROOT/install/artix/dinit/user/omarchy-fcitx5"

bash -n "$audio" "$xcompose"
for command in "$audio" "$xcompose"; do
  if rg -n '\bsystemctl\b|\bsystemd-run\b' "$command"; then
    fail "$(basename "$command") has no systemd runtime path"
  fi
done

grep -F 'dinitctl --user restart' "$audio" >/dev/null ||
  fail "audio recovery restarts dinit user services"
grep -F 'dinitctl --user stop --force' "$audio" >/dev/null ||
  fail "audio recovery can force-stop stuck dinit services"
grep -F 'dinitctl --user start pipewire pipewire-pulse wireplumber' "$audio" >/dev/null ||
  fail "audio recovery starts Artix PipeWire services"
grep -F 'dinitctl --user stop omarchy-fcitx5' "$xcompose" >/dev/null ||
  fail "XCompose stops the fcitx5 dinit service"
grep -F 'command = /usr/bin/fcitx5 --disable notificationitem' "$fcitx_service" >/dev/null ||
  fail "fcitx5 dinit service has the expected command"

pass "audio and XCompose recovery use dinit user services"
