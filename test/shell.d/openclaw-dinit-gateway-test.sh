#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

mkdir -p "$tmp_dir/bin" "$tmp_dir/home"
export HOME="$tmp_dir/home"
export XDG_CONFIG_HOME="$HOME/.config"
export TEST_LOG="$tmp_dir/log"
export PATH="$tmp_dir/bin:$PATH"

cat >"$tmp_dir/bin/dinitctl" <<'SCRIPT'
#!/bin/bash
printf 'dinitctl:%s\n' "$*" >>"$TEST_LOG"
case "${2:-}" in
list|start|stop) exit 0 ;;
status) echo '    Process ID: 4242'; exit 0 ;;
esac
SCRIPT
chmod +x "$tmp_dir/bin/dinitctl"

gateway="$ROOT/bin/omarchy-openclaw-gateway"
"$gateway" start

service="$XDG_CONFIG_HOME/dinit.d/openclaw-gateway"
boot_link="$XDG_CONFIG_HOME/dinit.d/boot.d/openclaw-gateway"

[[ -f $service ]] || fail "OpenClaw Gateway creates a dinit user service"
grep -qxF 'command = /usr/bin/openclaw gateway' "$service" ||
  fail "OpenClaw Gateway runs the foreground upstream command under dinit"
grep -qxF 'restart = true' "$service" || fail "OpenClaw Gateway restarts under dinit"
[[ -L $boot_link ]] || fail "OpenClaw Gateway starts on the dinit user boot target"
grep -q '^dinitctl:--user start openclaw-gateway$' "$TEST_LOG" ||
  fail "OpenClaw Gateway starts through dinit"
pass "OpenClaw Gateway is a persistent dinit user service"

"$gateway" remove
[[ ! -e $service && ! -L $boot_link ]] || fail "OpenClaw Gateway removal drops only its dinit service"
grep -q '^dinitctl:--user stop openclaw-gateway$' "$TEST_LOG" ||
  fail "OpenClaw Gateway stops through dinit before removal"
pass "OpenClaw Gateway removal is dinit-native"
