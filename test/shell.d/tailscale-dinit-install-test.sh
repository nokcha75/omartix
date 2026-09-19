#!/bin/bash

set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "$0")/base-test.sh"

install_source=$(<"$ROOT/bin/omarchy-install-service-tailscale")
remove_source=$(<"$ROOT/bin/omarchy-remove-service-tailscale")
status_source=$(<"$ROOT/bin/omarchy-installed-service-tailscale")

grep -qF 'omarchy-pkg-add tailscale tailscale-dinit' <<<"$install_source" ||
  fail "Tailscale installs the Artix dinit service package"
pass "Tailscale installs the Artix dinit service package"

if ! grep -qF 'sudo dinitctl enable tailscaled' <<<"$install_source" ||
  ! grep -qF 'sudo dinitctl start tailscaled' <<<"$install_source"; then
  fail "Tailscale enables and starts tailscaled through dinit"
fi
pass "Tailscale enables and starts tailscaled through dinit"

grep -qF 'systemctl' <<<"$install_source" &&
  fail "Tailscale installation does not invoke systemctl"
if ! grep -qF 'omarchy-tailscale-receive' <<<"$install_source" ||
  ! grep -qF 'dinitctl --user start omarchy-tailscale-receive' <<<"$install_source"; then
  fail "Taildrop receiver is a dinit user service"
fi
pass "Taildrop receiver is a dinit user service"

if ! grep -qF 'dinitctl --user stop omarchy-tailscale-receive' <<<"$remove_source" ||
  ! grep -qF 'sudo dinitctl disable tailscaled' <<<"$remove_source" ||
  ! grep -qF 'omarchy-pkg-drop tailscale tailscale-dinit' <<<"$remove_source"; then
  fail "Tailscale removal tears down dinit services and packages"
fi
pass "Tailscale removal tears down dinit services and packages"

grep -qF 'dinitctl is-started tailscaled' <<<"$status_source" ||
  fail "Tailscale status checks dinit before falling back to the daemon process"
pass "Tailscale status checks dinit before falling back to the daemon process"
