#!/bin/bash

set -euo pipefail

source "$(dirname "$0")/base-test.sh"

toggle="$ROOT/bin/omarchy-sudo-passwordless"
expire="$ROOT/bin/omarchy-sudo-passwordless-expire"

bash -n "$toggle" "$expire"
for file in "$toggle" "$expire"; do
  if rg -n '\bsystemctl\b|\bsystemd-run\b' "$file"; then
    fail "$(basename "$file") has no systemd dependency"
  fi
done

grep -F 'command = /usr/bin/omarchy-sudo-passwordless-expire $uid' "$toggle" >/dev/null ||
  fail "expiry uses a dinit service"
grep -F 'sudo ln -sfn "../$service" "$boot_link"' "$toggle" >/dev/null ||
  fail "expiry service is enabled for the next boot"
grep -F 'sudo visudo -cf "$sudoers_file"' "$toggle" >/dev/null ||
  fail "temporary sudoers rule is validated before activation"
grep -F 'remove_grant' "$toggle" >/dev/null ||
  fail "activation failures revoke the sudo grant"
grep -F 'rm -f "$state_file"' "$expire" >/dev/null ||
  fail "expiry revokes the sudo grant"
grep -F 'boot.d/omarchy-nopasswd-expire-$uid' "$expire" >/dev/null ||
  fail "expiry removes its dinit boot link"

pass "temporary passwordless sudo uses a fail-closed dinit expiry"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/bin"

cat >"$tmpdir/bin/gum" <<'EOF'
#!/bin/bash
exit 0
EOF
cat >"$tmpdir/bin/sudo" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >>"$OMARCHY_NOPASSWD_LOG"
case "${1:-}" in
  test)
    exit 1
    ;;
  tee)
    cat >/dev/null
    ;;
  install)
    [[ ${2:-} == -Dm644 ]] && cat >/dev/null || true
    ;;
  dinitctl)
    [[ ${2:-} == start && ${OMARCHY_NOPASSWD_FAIL_START:-false} == true ]] && exit 1
    ;;
  chmod|chown|ln|rm|visudo)
    ;;
  *)
    echo "unexpected sudo command: $*" >&2
    exit 90
    ;;
esac
exit 0
EOF
chmod +x "$tmpdir/bin/gum" "$tmpdir/bin/sudo"

log="$tmpdir/calls"
if OMARCHY_NOPASSWD_LOG="$log" PATH="$tmpdir/bin:$PATH" "$toggle" 15 >/dev/null; then
  :
else
  fail "passwordless sudo enables when its dinit worker starts"
fi
grep -q '^dinitctl start omarchy-nopasswd-expire-' "$log" ||
  fail "passwordless sudo starts its expiry worker before reporting success"

: >"$log"
if OMARCHY_NOPASSWD_LOG="$log" OMARCHY_NOPASSWD_FAIL_START=true PATH="$tmpdir/bin:$PATH" "$toggle" 15 >/dev/null 2>&1; then
  fail "passwordless sudo fails when the dinit expiry worker cannot start"
fi
grep -q '^rm -f /etc/dinit.d/boot.d/omarchy-nopasswd-expire-' "$log" ||
  fail "failed expiry startup removes the boot-time worker"
grep -q '/etc/sudoers.d/99-omarchy-nopasswd-' "$log" ||
  fail "failed expiry startup revokes the temporary sudo rule"

pass "passwordless sudo revokes access when dinit expiry startup fails"
