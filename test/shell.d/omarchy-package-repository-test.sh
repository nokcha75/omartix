#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

script="$ROOT/install/dinit/config/omarchy-package-repository.sh"

grep -qF 'print "Server = " server' "$script" || fail "package repository server is channel-derived"
grep -qF 'repository_url=${OMARTIX_PACKAGE_REPOSITORY_URL:-https://pkgs.omarchy.org}' "$script" ||
  fail "Omartix defaults to Omarchy's package repository"
grep -qF 'server="${repository_url%/}/$channel/\$arch"' "$script" ||
  fail "package repository URL is provider-configurable"
grep -qF 'SigLevel = Required DatabaseOptional' "$script" ||
  fail "Omarchy repository requires signed package files"
grep -qF 'pacman-key --lsign-key' "$script" ||
  fail "Omarchy repository bootstraps only its pinned signing key"
grep -qF 'pacman -Sy --noconfirm --needed "$keyring_package"' "$script" ||
  fail "package repository installs its configured updatable keyring"
grep -qF 'OMARTIX_PACKAGE_REPOSITORY_CONFIG' "$script" ||
  fail "package repository persists its trust configuration"
! grep -qE 'TrustAll|SigLevel = Never|mirror\.omarchy\.org' "$script" ||
  fail "Omarchy repository does not weaken signatures or replace Artix mirrors"
pass "Omarchy packages are added as a signed supplementary repository"

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT
mkdir -p "$tmp_dir/bin"

cat >"$tmp_dir/pacman.conf" <<'CONF'
[options]
Architecture = auto

[system]
Include = /etc/pacman.d/mirrorlist

[omarchy]
Server = https://pkgs.omarchy.org/stable/$arch
SigLevel = Never

[world]
Include = /etc/pacman.d/mirrorlist

[omarchy]
Server = https://obsolete.invalid/$arch
CONF

cat >"$tmp_dir/bin/pacman-key" <<'SCRIPT'
#!/bin/bash
exit 0
SCRIPT
cat >"$tmp_dir/bin/pacman" <<'SCRIPT'
#!/bin/bash
printf '%s\n' "$*" >>"$TEST_LOG"
SCRIPT
chmod +x "$tmp_dir/bin/pacman-key" "$tmp_dir/bin/pacman"

test_script="$tmp_dir/omarchy-package-repository.sh"
sed "s|^pacman_conf=/etc/pacman.conf$|pacman_conf=$tmp_dir/pacman.conf|" "$script" >"$test_script"
chmod +x "$test_script"
export TEST_LOG="$tmp_dir/log"
PATH="$tmp_dir/bin:$PATH" OMARCHY_MIRROR=rc OMARTIX_PACKAGE_REPOSITORY_CONFIG="$tmp_dir/package-repository.conf" "$test_script"

[[ $(grep -c '^\[omarchy\]$' "$tmp_dir/pacman.conf") == 1 ]] ||
  fail "Omarchy repository normalizes duplicate repository blocks"
grep -qx 'Server = https://pkgs.omarchy.org/rc/$arch' "$tmp_dir/pacman.conf" ||
  fail "Omarchy repository updates an existing channel selection"
grep -qx 'SigLevel = Required DatabaseOptional' "$tmp_dir/pacman.conf" ||
  fail "Omarchy repository repairs an unsafe existing signature policy"
grep -qx '\[system\]' "$tmp_dir/pacman.conf" && grep -qx '\[world\]' "$tmp_dir/pacman.conf" ||
  fail "Omarchy repository preserves Artix repository definitions"

PATH="$tmp_dir/bin:$PATH" OMARCHY_MIRROR=edge OMARTIX_PACKAGE_REPOSITORY_CONFIG="$tmp_dir/package-repository.conf" "$test_script"
grep -qx 'Server = https://pkgs.omarchy.org/edge/$arch' "$tmp_dir/pacman.conf" ||
  fail "Omarchy repository changes channel without adding another block"
[[ $(grep -c '^\[omarchy\]$' "$tmp_dir/pacman.conf") == 1 ]] ||
  fail "Omarchy repository stays idempotent when changing channel"
pass "Omarchy repository safely updates its own existing block"

PATH="$tmp_dir/bin:$PATH" OMARCHY_MIRROR=stable \
  OMARTIX_PACKAGE_REPOSITORY_NAME=omartix \
  OMARTIX_PACKAGE_REPOSITORY_URL=https://packages.example.invalid \
  OMARTIX_PACKAGE_SIGNING_FINGERPRINT=0123456789ABCDEF0123456789ABCDEF01234567 \
  OMARTIX_PACKAGE_SIGNING_KEY_URL=https://packages.example.invalid/omartix.gpg \
  OMARTIX_PACKAGE_KEYRING_PACKAGE=omartix-keyring \
  OMARTIX_PACKAGE_REPOSITORY_CONFIG="$tmp_dir/package-repository.conf" \
  "$test_script"
grep -qx '\[omartix\]' "$tmp_dir/pacman.conf" ||
  fail "an Omartix repository name can replace the default supplementary repository"
grep -qx 'Server = https://packages.example.invalid/stable/$arch' "$tmp_dir/pacman.conf" ||
  fail "an Omartix repository URL is persisted into pacman"
grep -qx 'OMARTIX_PACKAGE_KEYRING_PACKAGE=omartix-keyring' "$tmp_dir/package-repository.conf" ||
  fail "the selected Omartix keyring package is persisted for later updates"
pass "Omartix can adopt a future signed package host without changing installer code"

cat >"$tmp_dir/pacman.conf" <<'CONF'
[options]
Architecture = auto

[system]
Include = /etc/pacman.d/mirrorlist
CONF
PATH="$tmp_dir/bin:$PATH" OMARCHY_MIRROR=stable \
  OMARTIX_PACKAGE_REPOSITORY_USE_SAVED=1 \
  OMARTIX_PACKAGE_REPOSITORY_CONFIG="$tmp_dir/package-repository.conf" \
  "$test_script"
grep -qx '\[omartix\]' "$tmp_dir/pacman.conf" ||
  fail "saved Omartix repository selection survives pacman configuration restore"
grep -qx 'Server = https://packages.example.invalid/stable/$arch' "$tmp_dir/pacman.conf" ||
  fail "saved Omartix repository URL is reapplied after configuration restore"
pass "saved package repository trust can be reapplied after offline installation"

post_install="$ROOT/install/post-install/pacman.sh"
grep -qF 'OMARTIX_PACKAGE_REPOSITORY_USE_SAVED=1' "$post_install" ||
  fail "post-install pacman setup reapplies the saved package repository trust"
grep -qF 'dinit/config/omarchy-package-repository.sh' "$post_install" ||
  fail "post-install pacman setup uses the single dinit package repository configurator"
pass "post-install pacman restoration preserves the selected supplementary repository"
