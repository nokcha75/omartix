#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

script="$ROOT/bin/omartix-update-keyring"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/bin" "$tmpdir/state"

fingerprint=0123456789ABCDEF0123456789ABCDEF01234567
cat >"$tmpdir/package-repository.conf" <<EOF
OMARTIX_PACKAGE_SIGNING_FINGERPRINT=$fingerprint
OMARTIX_PACKAGE_SIGNING_KEY_URL=https://packages.example.invalid/omartix.gpg
OMARTIX_PACKAGE_KEYRING_PACKAGE=omartix-keyring
EOF

cat >"$tmpdir/bin/omarchy-pkg-missing" <<'SCRIPT'
#!/bin/bash
exit 0
SCRIPT
cat >"$tmpdir/bin/omarchy-cmd-present" <<'SCRIPT'
#!/bin/bash
command -v "$1" >/dev/null
SCRIPT
cat >"$tmpdir/bin/sudo" <<'SCRIPT'
#!/bin/bash
exec "$@"
SCRIPT
cat >"$tmpdir/bin/pacman-key" <<'SCRIPT'
#!/bin/bash
case "$1" in
  --list-keys) [[ -e "$TEST_STATE/key-added" ]] && exit 0 || exit 1 ;;
  --add) touch "$TEST_STATE/key-added" ;;
esac
printf 'pacman-key:%s\n' "$*" >>"$TEST_LOG"
SCRIPT
cat >"$tmpdir/bin/curl" <<'SCRIPT'
#!/bin/bash
while (( $# > 0 )); do
  [[ $1 == -o ]] && { printf fake-key >"$2"; exit 0; }
  shift
done
exit 1
SCRIPT
cat >"$tmpdir/bin/gpg" <<'SCRIPT'
#!/bin/bash
printf 'fpr:::::::::%s:\n' "$TEST_FINGERPRINT"
SCRIPT
cat >"$tmpdir/bin/pacman" <<'SCRIPT'
#!/bin/bash
printf 'pacman:%s\n' "$*" >>"$TEST_LOG"
SCRIPT
cat >"$tmpdir/bin/omarchy-pkg-add" <<'SCRIPT'
#!/bin/bash
printf 'omarchy-pkg-add:%s\n' "$*" >>"$TEST_LOG"
SCRIPT
chmod +x "$tmpdir/bin"/*

TEST_STATE="$tmpdir/state" TEST_LOG="$tmpdir/log" TEST_FINGERPRINT="$fingerprint" \
  PATH="$tmpdir/bin:$PATH" OMARTIX_PACKAGE_REPOSITORY_CONFIG="$tmpdir/package-repository.conf" \
  "$script" >/dev/null

grep -Fx "pacman-key:--lsign-key $fingerprint" "$tmpdir/log" >/dev/null ||
  fail "keyring update trusts the persisted Omartix signing key"
grep -Fx 'omarchy-pkg-add:omartix-keyring' "$tmpdir/log" >/dev/null ||
  fail "keyring update installs the persisted Omartix keyring package"
pass "keyring updates follow the persisted supplementary package repository trust"
