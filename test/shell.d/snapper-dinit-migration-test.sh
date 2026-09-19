#!/bin/bash

set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "$0")/base-test.sh"

migration="$ROOT/migrations/1781984677.sh"
test_dir=$(mktemp -d)
call_log="$test_dir/calls"
config_script="$test_dir/snapper.sh"
trap 'rm -rf "$test_dir"' EXIT
printf '#!/bin/bash\nexit 0\n' >"$config_script"
chmod +x "$config_script"

(
  # shellcheck disable=SC2329
  omarchy-pkg-add() { printf 'pkg:%s\n' "$*" >>"$call_log"; }
  # shellcheck disable=SC2329
  sudo() { "$@"; }
  # shellcheck disable=SC2329
  dinitctl() { printf 'dinit:%s\n' "$*" >>"$call_log"; }

  OMARCHY_PATH="$test_dir"
  export OMARCHY_PATH
  mkdir -p "$test_dir/install/dinit/config"
  cp "$config_script" "$test_dir/install/dinit/config/snapper.sh"
  # shellcheck disable=SC1090
  source "$migration"
)

grep -Fx 'pkg:limine-snapper-sync limine-snapper-sync-dinit' "$call_log" >/dev/null ||
  fail "Snapper migration installs Artix dinit snapshot sync"
for call in 'dinit:enable omarchy-snapper-cleanup' 'dinit:start omarchy-snapper-cleanup' 'dinit:enable limine-snapper-sync' 'dinit:start limine-snapper-sync'; do
  grep -Fx "$call" "$call_log" >/dev/null || fail "Snapper migration runs $call"
done
pass "Snapper migration restores cleanup and Limine sync through dinit"

if rg -n '\bsystemctl\b' "$migration" >/dev/null; then
  fail "Snapper migration has no systemd service-manager path"
fi
pass "Snapper migration is dinit-only"
