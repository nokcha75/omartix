#!/bin/bash

set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "$0")/base-test.sh"

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

mock_bin="$test_tmp/bin"
boot_dir="$test_tmp/boot.d"
service="$test_tmp/thermald"
package_log="$test_tmp/packages"
mkdir -p "$mock_bin"
touch "$service"

cat >"$mock_bin/grep" <<'SH'
#!/bin/bash
printf 'model\t: 42\n'
SH
cat >"$mock_bin/omarchy-pkg-add" <<'SH'
#!/bin/bash
printf '%s\n' "$*" >>"$OMARTIX_TEST_PACKAGE_LOG"
SH
cat >"$mock_bin/sudo" <<'SH'
#!/bin/bash
exec "$@"
SH
cat >"$mock_bin/omarchy-hw-intel" <<'SH'
#!/bin/bash
exit 0
SH
cat >"$mock_bin/omarchy-battery-present" <<'SH'
#!/bin/bash
exit 0
SH
chmod +x "$mock_bin"/*

PATH="$mock_bin:$PATH" \
  OMARTIX_DINIT_BOOT_DIR="$boot_dir" \
  OMARTIX_THERMALD_DINIT_SERVICE="$service" \
  OMARTIX_TEST_PACKAGE_LOG="$package_log" \
  bash "$ROOT/install/hardware/intel/thermald.sh"

grep -Fx 'thermald thermald-dinit' "$package_log" >/dev/null ||
  fail "Intel thermal setup installs the Artix dinit companion"
[[ -L $boot_dir/thermald && $(readlink "$boot_dir/thermald") == ../thermald ]] ||
  fail "Intel thermal setup enables thermald through dinit boot.d"
! rg -q '\b(systemctl|systemd-run)\b' "$ROOT/install/hardware/intel/thermald.sh" ||
  fail "Intel thermal setup has no systemd service path"
pass "Intel thermal management uses the official dinit service"
