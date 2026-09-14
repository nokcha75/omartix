#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

tuning="$ROOT/bin/omarchy-audio-tuning"
first_run="$ROOT/bin/omarchy-provision-first-run"

bash -n "$tuning" "$first_run"
! grep -Eq 'systemctl|systemd' "$tuning" || fail "speaker tuning has no systemd runtime path"
grep -F 'command = /usr/bin/pipewire -c omarchy-speaker-tuning.conf' "$tuning" >/dev/null ||
  fail "speaker tuning runs as a dinit-managed PipeWire client"
grep -F 'depends-on = pipewire wireplumber' "$tuning" >/dev/null ||
  fail "speaker tuning waits for PipeWire and WirePlumber"
grep -F 'dinitctl --user restart "$unit_name"' "$tuning" >/dev/null ||
  fail "speaker tuning restarts through dinit"
grep -F 'dinitctl --user stop "$unit_name"' "$tuning" >/dev/null ||
  fail "speaker tuning stops through dinit"
grep -F 'apply speaker tuning' "$first_run" >/dev/null ||
  fail "first-run provisioning applies speaker tuning"

pass "speaker tuning functionality uses a dinit user service"
