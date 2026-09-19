#!/bin/bash

set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "$0")/base-test.sh"

installer="$ROOT/bin/omarchy-install-service-once"

bash -n "$installer"
if rg -n '\bsystemctl\b|\bsystemd-run\b' "$installer"; then
  fail "ONCE has no systemd runtime path"
fi

grep -F 'omarchy-pkg-add once-bin' "$installer" >/dev/null ||
  fail "ONCE keeps the existing remote package installation path"
grep -F '/etc/dinit.d/once-background' "$installer" >/dev/null ||
  fail "ONCE installs its dinit adapter"
grep -F 'command = /usr/bin/env ONCE_NO_SELF_UPDATE=1 /usr/bin/once background run --namespace once' "$installer" >/dev/null ||
  fail "ONCE dinit adapter preserves Omarchy's background command and environment"
grep -F 'depends-on = network.target dockerd' "$installer" >/dev/null ||
  fail "ONCE waits for network and Docker"
grep -F 'sudo dinitctl enable once-background' "$installer" >/dev/null ||
  fail "ONCE enables its dinit background service"

pass "ONCE uses a dinit adapter for the upstream package service"
