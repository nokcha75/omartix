#!/bin/bash

set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "$0")/base-test.sh"

tuning="$ROOT/bin/omarchy-audio-tuning"
first_run="$ROOT/bin/omarchy-provision-first-run"

bash -n "$tuning" "$first_run"
if rg -n '\bsystemctl\b|\bsystemd-run\b' "$tuning"; then
  fail "speaker tuning has no systemd runtime path"
fi

grep -F 'command = /usr/bin/pipewire -c omarchy-speaker-tuning.conf' "$tuning" >/dev/null ||
  fail "speaker tuning runs as a dinit-managed PipeWire client"
grep -F 'depends-on = pipewire wireplumber' "$tuning" >/dev/null ||
  fail "speaker tuning waits for PipeWire and WirePlumber"
# shellcheck disable=SC2016
grep -F 'dinitctl --user restart "$unit_name"' "$tuning" >/dev/null ||
  fail "speaker tuning restarts through dinit"
# shellcheck disable=SC2016
grep -F 'dinitctl --user stop "$unit_name"' "$tuning" >/dev/null ||
  fail "speaker tuning stops through dinit"
grep -F 'apply speaker tuning' "$first_run" >/dev/null ||
  fail "first-run provisioning applies speaker tuning"

pass "speaker tuning functionality uses a dinit user service"
