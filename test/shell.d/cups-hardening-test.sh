#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

packages="$ROOT/install/omarchy-base.packages"
cups_files_conf="$ROOT/etc-overrides/cups-cups-files.conf"

# Only discovery goes. Everything else printing needs stays, or this stops
# being a removal of one daemon and becomes a removal of printing.
grep -qxF cups "$packages" || fail "CUPS itself remains in the base package set"
grep -qxF cups-filters "$packages" || fail "the CUPS filters remain in the base package set"
grep -qxF system-config-printer "$packages" || fail "Print Settings remains in the base package set"
grep -qxF cups-pk-helper "$packages" || fail "Polkit printer administration is installed"
! grep -qxF cups-pdf "$packages" || fail "the root CUPS-PDF backend is removed"

# Automatic discovery is temporarily out of the default install while it is
# reworked. The hardened configuration below stays as the baseline discovery
# comes back onto.
! grep -qxF cups-browsed "$packages" || fail "automatic printer discovery is out of the base package set"
! grep -q 'cups-browsed' "$ROOT/install/dinit/config/enable-services.sh" ||
  fail "a fresh install does not enable a discovery service it no longer installs"
pass "the base install keeps CUPS and Polkit administration, without automatic discovery"

# CUPS still ships /etc/cups/cups-files.conf, so its authorization override is
# applied after the ISO installs that package. cups-browsed is absent, so the
# installer must not write any of its package-owned configuration.
post_install_pacman="$ROOT/install/post-install/pacman.sh"

! grep -q 'cups-cups-browsed.conf' "$post_install_pacman" ||
  fail "a fresh install does not write configuration for absent printer discovery"
grep -q 'cups-cups-files.conf && -f /etc/cups/cups-files.conf' "$post_install_pacman" ||
  fail "the CUPS authorization override waits for the file it replaces"
grep -q 'plymouth-plymouthd.conf && -f /etc/plymouth/plymouthd.conf' "$post_install_pacman" ||
  fail "the Plymouth theme override waits for the file it replaces"

pass "the fresh install applies CUPS hardening without writing discovery configuration"

grep -qxF 'SystemGroup sys root' "$cups_files_conf" ||
  fail "CUPS administration stays with system administrators"
grep -qxF 'PeerCred on' "$cups_files_conf" ||
  fail "the packaged CUPS policy enables peer credentials"
[[ $(grep -ciE '^[[:space:]]*SystemGroup[[:space:]]' "$cups_files_conf") == 1 ]] ||
  fail "the packaged CUPS policy has one SystemGroup directive"
[[ $(grep -ciE '^[[:space:]]*PeerCred[[:space:]]' "$cups_files_conf") == 1 ]] ||
  fail "the packaged CUPS policy has one PeerCred directive"
[[ ! -e $ROOT/install/config/printing.sh ]] ||
  fail "printing policy is not rewritten by an install script"
! grep -q 'config/printing.sh' "$ROOT/install/dinit/config/all.sh" "$ROOT/migrations/1787815267.sh" ||
  fail "neither install nor update invokes a printing rewrite script"

pass "CUPS authorization ships as a canonical package override"

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

mock_bin="$test_tmp/bin"
mkdir -p "$mock_bin" "$test_tmp/var/lib/omarchy/migrations"

passwd_db="$test_tmp/passwd"
group_db="$test_tmp/group"
touch "$passwd_db" "$group_db"

cat >"$mock_bin/getent" <<'SH'
#!/bin/bash
case "$1" in
  passwd) database="$OMARCHY_CUPS_TEST_PASSWD" ;;
  group) database="$OMARCHY_CUPS_TEST_GROUP" ;;
  *) exit 2 ;;
esac

if (($# == 1)); then
  cat "$database"
else
  awk -F: -v name="$2" '$1 == name { print; found = 1 } END { exit !found }' "$database"
fi
SH
cat >"$mock_bin/omarchy-pkg-present" <<'SH'
#!/bin/bash
[[ $1 == "cups" || $1 == "cups-browsed" ]]
SH
for command in omarchy-pkg-add omarchy-pkg-drop; do
  cat >"$mock_bin/$command" <<'SH'
#!/bin/bash
printf '%s\t%s\n' "${0##*/}" "$*" >>"$OMARCHY_CUPS_TEST_LOG"
SH
done
cat >"$mock_bin/dinitctl" <<'SH'
#!/bin/bash
printf 'dinitctl\t%s\n' "$*" >>"$OMARCHY_CUPS_TEST_LOG"
SH
cat >"$mock_bin/pkill" <<'SH'
#!/bin/bash
printf 'pkill\t%s\n' "$*" >>"$OMARCHY_CUPS_TEST_LOG"
SH
cat >"$mock_bin/sudo" <<'SH'
#!/bin/bash
printf 'sudo\t%s\n' "$*" >>"$OMARCHY_CUPS_TEST_LOG"
exec "$@"
SH
chmod +x "$mock_bin"/*

log="$test_tmp/actions.log"
touch "$log"
export OMARCHY_CUPS_TEST_LOG="$log"
export OMARCHY_CUPS_TEST_PASSWD="$passwd_db"
export OMARCHY_CUPS_TEST_GROUP="$group_db"

printf 'cups-browsed:x:1000:1000:Desktop user:/home/cups-browsed:/usr/bin/bash\n' >"$passwd_db"
printf 'cups-browsed:x:1000:\n' >"$group_db"
if PATH="$mock_bin:$PATH" \
  OMARCHY_PATH="$ROOT" \
  OMARCHY_CUPS_MIGRATION_MARKER="$test_tmp/desktop-collision-marker" \
  bash -euo pipefail "$ROOT/migrations/1787815267.sh" 2>/dev/null; then
  fail "the migration accepts an existing desktop user named cups-browsed"
fi
[[ ! -s $log ]] || fail "an account collision stops the migration before changing the system"

printf 'alice:x:1000:947:Desktop user:/home/alice:/usr/bin/bash\n' >"$passwd_db"
printf 'cups-browsed:x:947:alice\n' >"$group_db"
if PATH="$mock_bin:$PATH" \
  OMARCHY_PATH="$ROOT" \
  OMARCHY_CUPS_MIGRATION_MARKER="$test_tmp/group-collision-marker" \
  bash -euo pipefail "$ROOT/migrations/1787815267.sh" 2>/dev/null; then
  fail "the migration accepts an existing cups-browsed group with members"
fi
[[ ! -s $log ]] || fail "a group collision stops the migration before changing the system"

printf 'cups-browsed:x:947:947:CUPS printer discovery:/:/usr/bin/nologin\n' >"$passwd_db"
printf 'cups-browsed:x:947:\n' >"$group_db"

pass "the migration rejects account and group collisions before changing printing"

marker="$test_tmp/var/lib/omarchy/migrations/1787815267"
PATH="$mock_bin:$PATH" \
  OMARCHY_PATH="$ROOT" \
  OMARCHY_CUPS_MIGRATION_MARKER="$marker" \
  bash -euo pipefail "$ROOT/migrations/1787815267.sh"

grep -qxF $'omarchy-pkg-drop\tcups-pdf' "$log" ||
  fail "the migration removes CUPS-PDF"
grep -qxF $'omarchy-pkg-add\tcups-pk-helper' "$log" ||
  fail "the migration installs authenticated printer administration"
grep -qxF $'pkill\t-x cups-browsed' "$log" ||
  fail "the migration stops a legacy cups-browsed process before reconfiguration"
grep -qxF $'dinitctl\trestart cups' "$log" ||
  fail "the migration restarts the Artix CUPS service"
[[ -f $marker ]] || fail "the migration records machine-wide completion"

actions_after_first_run=$(wc -l <"$log")
PATH="$mock_bin:$PATH" \
  OMARCHY_PATH="$ROOT" \
  OMARCHY_CUPS_MIGRATION_MARKER="$marker" \
  bash -euo pipefail "$ROOT/migrations/1787815267.sh"
[[ $(wc -l <"$log") == "$actions_after_first_run" ]] ||
  fail "the machine-wide migration repeats privileged work"

! rg -q 'systemctl|cups-browsed\.service' "$ROOT/migrations/1787815267.sh" ||
  fail "the migration does not retain a systemd-only cups-browsed service path"

pass "the migration safely converts an active existing installation once"
