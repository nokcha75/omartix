#!/bin/bash

set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "$0")/base-test.sh"

migration="$ROOT/migrations/1786567036.sh"
test_dir=$(mktemp -d)
stub_bin="$test_dir/bin"
call_log="$test_dir/calls"
trap 'rm -rf "$test_dir"' EXIT
mkdir -p "$stub_bin"

cat >"$stub_bin/dinitctl" <<'SCRIPT'
#!/bin/bash
[[ $1 == is-started && $2 == NetworkManager ]] && exit 0
printf 'dinit:%s\n' "$*" >>"$TEST_LOG"
SCRIPT
cat >"$stub_bin/nmcli" <<'SCRIPT'
#!/bin/bash
printf 'wifi:unavailable\n'
SCRIPT
cat >"$stub_bin/sudo" <<'SCRIPT'
#!/bin/bash
"$@"
SCRIPT
chmod +x "$stub_bin"/*

PATH="$stub_bin:$PATH" TEST_LOG="$call_log" bash -euo pipefail "$migration" >/dev/null
grep -Fx 'dinit:restart NetworkManager' "$call_log" >/dev/null ||
  fail "Wi-Fi migration restarts unavailable NetworkManager through dinit"
pass "Wi-Fi migration recovers NetworkManager through dinit"

if rg -n '\bsystemctl\b|wpa_supplicant\.service' "$migration" >/dev/null; then
  fail "Wi-Fi migration has no systemd mask path"
fi
pass "Wi-Fi migration relies on Artix NetworkManager dependency management"
