#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

template="$ROOT/default/snapper/root"
limine_defaults="$ROOT/etc/limine-entry-tool.d/omarchy-defaults.conf"
limine_notify_autostart="$ROOT/config/autostart/limine-snapper-notify.desktop"

grep -Fx 'NUMBER_CLEANUP="yes"' "$template" >/dev/null
grep -Fx 'NUMBER_LIMIT="5"' "$template" >/dev/null
grep -Fx 'TIMELINE_CREATE="no"' "$template" >/dev/null
! grep -Eq '^TIMELINE_(CLEANUP|LIMIT_)' "$template" || fail "Snapper template keeps timeline cleanup details out of the default config"
grep -Fx 'MAX_SNAPSHOT_ENTRIES=6' "$limine_defaults" >/dev/null || fail "Limine allows for a snapshot created before Snapper cleanup"
pass "Snapper and Limine retain update snapshots without a transient limit mismatch"

grep -Fx '[Desktop Entry]' "$limine_notify_autostart" >/dev/null
grep -Fx 'Hidden=true' "$limine_notify_autostart" >/dev/null
pass "Limine Snapper warning notifier is disabled by default"

notification_migration=$(grep -rl 'Disable Limine Snapper warning notifier' "$ROOT/migrations" | head -n 1 || true)
[[ -n $notification_migration ]] || fail "Limine Snapper warning notifier migration exists"
grep -F 'limine-snapper-notify.desktop' "$notification_migration" >/dev/null

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

migration_home="$test_tmp/migration-home"
mkdir -p "$migration_home"
HOME="$migration_home" bash -euo pipefail "$notification_migration" >/dev/null

cmp -s "$limine_notify_autostart" "$migration_home/.config/autostart/limine-snapper-notify.desktop" || fail "Limine Snapper warning notifier migration writes autostart override"
pass "Limine Snapper warning notifier migration disables existing user autostart"

setup_system="$ROOT/bin/omarchy-apply-system"
grep -F 'dinit/config/all.sh' "$setup_system" >/dev/null ||
  fail "system setup runs the config phase"
grep -F 'dinit/config/snapper.sh' "$ROOT/install/dinit/config/all.sh" >/dev/null ||
  fail "config phase normalizes Snapper"
pass "system setup normalizes Snapper through dinit during fresh installs"

migration=$(grep -rl 'Normalize Snapper snapshot services' "$ROOT/migrations" | head -n 1 || true)
[[ -n $migration ]] || fail "Snapper service migration exists"
grep -F 'as_root dinitctl enable "$service"' "$migration" >/dev/null
grep -F 'as_root dinitctl start "$service"' "$migration" >/dev/null
grep -F 'install/dinit/config/snapper.sh' "$migration" >/dev/null
! grep -F 'NUMBER_LIMIT="5"' "$migration" >/dev/null || fail "Snapper service migration does not overwrite working custom retention"
pass "Snapper service migration repairs dinit services without changing retention"

# Checkouts differ per machine, so allow an explicit pointer at the sibling repo.
# Accepts either the omarchy-pkgs checkout or its pkgbuilds/ directory.
find_omarchy_pks_root() {
  local candidate
  for candidate in \
    ${OMARCHY_PKGS_PATH:+"$OMARCHY_PKGS_PATH/pkgbuilds" "$OMARCHY_PKGS_PATH"} \
    "$ROOT/../omarchy-pkgs/pkgbuilds" \
    "$ROOT/../omarchy/omarchy-pkgs/pkgbuilds" \
    "$ROOT/../../omarchy-pkgs/pkgbuilds" \
    "$ROOT/../omacom/omarchy-pkgs/pkgbuilds" \
    "$ROOT/../../omacom/omarchy-pkgs/pkgbuilds" \
    "$HOME/Work/omacom/omarchy-pkgs/pkgbuilds"; do
    if [[ -d $candidate ]]; then
      cd "$candidate" && pwd
      return 0
    fi
  done
  return 1
}

pkgs_root=$(find_omarchy_pks_root) || fail "omarchy-pkgs checkout is available for packaging coverage"
settings_pkgbuild="$pkgs_root/omarchy-settings-dev/PKGBUILD"
omarchy_pkgbuild="$pkgs_root/omarchy-dev/PKGBUILD"

grep -F 'cp -a default/. "$pkgdir/usr/share/omarchy/default/"' "$settings_pkgbuild" >/dev/null || fail "omarchy-settings package bundles default/"
grep -F 'install -Dm644 default/snapper/root \' "$settings_pkgbuild" >/dev/null || fail "omarchy-settings package installs Snapper template source"
grep -F '"$pkgdir/etc/snapper/config-templates/omarchy"' "$settings_pkgbuild" >/dev/null || fail "omarchy-settings package installs Snapper template destination"
grep -F "'snapper'" "$omarchy_pkgbuild" >/dev/null || fail "omarchy package depends on snapper"
grep -F "'limine-snapper-sync'" "$omarchy_pkgbuild" >/dev/null || fail "omarchy package depends on limine-snapper-sync"
grep -F 'cp -a install "$pkgdir/usr/share/omarchy/"' "$omarchy_pkgbuild" >/dev/null || fail "omarchy package bundles install scripts"
grep -F 'cp -a migrations "$pkgdir/usr/share/omarchy/"' "$omarchy_pkgbuild" >/dev/null || fail "omarchy package bundles migrations"
pass "omarchy-pkgs packages Snapper template, setup, and migration coverage"

# Same per-machine checkout problem as omarchy-pkgs; OMARCHY_ISO_PATH points at it.
find_omarchy_iso_root() {
  local candidate
  for candidate in \
    ${OMARCHY_ISO_PATH:+"$OMARCHY_ISO_PATH"} \
    "$ROOT/../omarchy-iso" \
    "$ROOT/../omarchy/omarchy-iso" \
    "$ROOT/../../omarchy-iso" \
    "$ROOT/../omacom/omarchy-iso" \
    "$ROOT/../../omacom/omarchy-iso" \
    "$HOME/Work/omacom/omarchy-iso"; do
    if [[ -d $candidate ]]; then
      cd "$candidate" && pwd
      return 0
    fi
  done
  return 1
}

iso_root=$(find_omarchy_iso_root) || fail "omarchy-iso checkout is available for installer coverage"
configurator="$iso_root/configs/airootfs/root/configurator"
phases="$iso_root/configs/airootfs/usr/share/omarchy-iso/orchestrator/phases_impl.py"
manifest="$iso_root/manifests/fresh-4-semantic.json"

! grep -F 'snapshot_config' "$configurator" >/dev/null || fail "ISO does not ask archinstall to create Snapper timeline config"

# The phases/manifest assertions cover the newer ISO orchestrator structure.
# Skip them when the checkout predates that layout.
if [[ -f $phases && -f $manifest ]]; then
  ! grep -F '_configure_snapper_root' "$phases" >/dev/null || fail "ISO does not duplicate Omarchy Snapper setup"
  grep -F 'run_system_finalizer' "$phases" >/dev/null || fail "ISO runs packaged system setup"
  grep -F '/etc/systemd/system/timers.target.wants/snapper-cleanup.timer' "$manifest" >/dev/null || fail "fresh ISO manifest has snapper-cleanup timer enabled"
  ! grep -F '/etc/systemd/system/timers.target.wants/snapper-timeline.timer' "$manifest" >/dev/null || fail "fresh ISO manifest does not enable snapper timeline timer"
fi
pass "omarchy-iso delegates Snapper setup to packaged system setup"
