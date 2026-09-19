#!/bin/bash
#
# Release-gate smoke test for the Artix+dinit installer.  It runs against the
# encrypted base image produced by integration.d/base-test.sh; no host disk is
# ever passed to QEMU.

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

base_image_ready || { echo "No base image; run this through ./test/integration" >&2; exit 1; }

log "Booting the encrypted Omartix installation smoke-test overlay"
start_vm_from_base
unlock_encrypted_boot
wait_for_ssh "$BOOT_TIMEOUT"

check "PID 1 is dinit" ssh_guest "test \"\$(cat /proc/1/comm)\" = dinit"
check "encrypted root partition is LUKS2" ssh_sudo "cryptsetup isLuks /dev/vda2"
check "root is unlocked through omarchy_root" ssh_guest "findmnt -n -o SOURCE / | grep -Eq '^/dev/mapper/omarchy_root(\\[.*\\])?$'"
check "Omartix app launcher is installed" ssh_guest "test -x /usr/bin/omartix-app"
check "UWSM launcher is not installed" ssh_guest "test ! -e /usr/bin/uwsm-app"
check "dinit network service is enabled" ssh_sudo "test -L /etc/dinit.d/boot.d/NetworkManager"
check "installed Omartix core package is present" ssh_guest "pacman -Q omartix"

capture_console "success-installer-smoke"
finish
