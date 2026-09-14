#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/bin"

cat >"$tmpdir/bin/dinitctl" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >>"$OMARCHY_SESSION_LOG"
[[ $2 == list ]] && exit 0
exit 0
EOF
cat >"$tmpdir/bin/dbus-update-activation-environment" <<'EOF'
#!/bin/bash
printf 'dbus %s\n' "$*" >>"$OMARCHY_SESSION_LOG"
exit 0
EOF
chmod +x "$tmpdir/bin/"*

log="$tmpdir/dinit.log"
OMARCHY_SESSION_LOG="$log" OMARCHY_SESSION_TEST=artix PATH="$tmpdir/bin:$PATH" \
  "$ROOT/bin/omarchy-session-init"
grep -Fx -- '--user setenv OMARCHY_SESSION_TEST=artix' "$log" >/dev/null ||
  fail "dinit session receives the Hyprland environment"
grep -F systemctl "$log" >/dev/null && fail "dinit session does not invoke systemctl"
grep -Fx -- 'dbus --all' "$log" >/dev/null ||
  fail "dinit session updates D-Bus activation without systemd"
pass "dinit session environment import avoids systemctl"

cat >"$tmpdir/bin/dinitctl" <<'EOF'
#!/bin/bash
exit 1
EOF
chmod +x "$tmpdir/bin/dinitctl"

if OMARCHY_SESSION_LOG="$tmpdir/failure.log" PATH="$tmpdir/bin:$PATH" \
  "$ROOT/bin/omarchy-session-init"; then
  fail "session init rejects a missing dinit user manager"
fi
pass "session init requires the dinit user manager"
