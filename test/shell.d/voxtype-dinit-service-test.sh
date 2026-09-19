#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

service="$ROOT/bin/omarchy-voxtype-service"
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT
mkdir -p "$tmp_dir/bin" "$tmp_dir/home"
export HOME="$tmp_dir/home"
export XDG_CONFIG_HOME="$HOME/.config"
export TEST_LOG="$tmp_dir/log"

cat >"$tmp_dir/bin/dinitctl" <<'SCRIPT'
#!/bin/bash
printf '%s\n' "$*" >>"$TEST_LOG"
exit 0
SCRIPT
chmod +x "$tmp_dir/bin/dinitctl"
export PATH="$tmp_dir/bin:$PATH"

"$service" start

service_file="$XDG_CONFIG_HOME/dinit.d/voxtype"
boot_link="$XDG_CONFIG_HOME/dinit.d/boot.d/voxtype"
[[ -f $service_file ]] || fail "Voxtype installs an Omartix dinit user service"
[[ -L $boot_link ]] || fail "Voxtype service starts on future user-manager boots"
grep -qx 'command = /usr/bin/voxtype -q daemon' "$service_file" ||
  fail "Voxtype dinit service runs the daemon directly"
grep -qx 'restart = true' "$service_file" ||
  fail "Voxtype dinit service restarts after a daemon failure"
grep -qx -- '--user start voxtype' "$TEST_LOG" ||
  fail "Voxtype dinit service starts immediately after installation"
pass "Voxtype uses a persistent dinit user service"

"$service" remove
[[ ! -e $service_file && ! -L $boot_link ]] ||
  fail "Voxtype removal deletes its Omartix dinit service"
grep -qx -- '--user stop voxtype' "$TEST_LOG" ||
  fail "Voxtype removal asks dinit to stop the daemon first"
pass "Voxtype removal is dinit-native"

! rg -q '\b(systemctl|systemd-run|systemd-inhibit)\b' \
  "$ROOT/bin/omarchy-voxtype-install" "$ROOT/bin/omarchy-voxtype-remove" "$service" ||
  fail "Voxtype installation and removal do not call systemd"
pass "Voxtype lifecycle has no systemd runtime path"
