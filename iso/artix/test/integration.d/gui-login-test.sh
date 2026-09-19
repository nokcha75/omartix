#!/bin/bash
#
# Boot the installed encrypted image far enough to see the graphical session.
# Encrypted installs enable SDDM autologin, so the first painted UI is the
# Omarchy/Hyprland session rather than a password greeter.

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

base_image_ready || { echo "No base image; run this through ./test/integration" >&2; exit 1; }

log "Booting the installed system to the graphical session"
start_vm_from_base
unlock_encrypted_boot
wait_for_ssh "$BOOT_TIMEOUT"

check "PID 1 is dinit" ssh_guest "test \"\$(cat /proc/1/comm)\" = dinit"
check "sddm is enabled" ssh_sudo "test -L /etc/dinit.d/boot.d/sddm"
check "tty1 is reserved for SDDM" ssh_guest "grep -Fq 'ACTIVE_CONSOLES=\"/dev/tty[2-6]\"' /etc/dinit.d/config/console.conf"
check "Omarchy SDDM theme is installed" ssh_guest "test -f /usr/share/sddm/themes/omarchy/Main.qml"

waited=0
while ! ssh_guest "pgrep -x sddm >/dev/null"; do
  if ! vm_running; then
    echo "VM exited while waiting for sddm" >&2
    exit 1
  fi
  if (( waited >= 180 )); then
    capture_console "failure-sddm-timeout"
    echo "Timed out waiting for sddm" >&2
    exit 1
  fi
  sleep 5
  (( waited += 5 ))
done
check "sddm process is running" ssh_guest "pgrep -x sddm >/dev/null"

if ssh_guest "test -f /etc/sddm.conf.d/autologin.conf"; then
  log "Encrypted install has SDDM autologin; waiting for Hyprland"
  waited=0
  while ! ssh_guest "pgrep -x Hyprland >/dev/null"; do
    if ! vm_running; then
      echo "VM exited while waiting for Hyprland" >&2
      exit 1
    fi
    if (( waited >= 240 )); then
      capture_console "failure-hyprland-timeout"
      echo "Timed out waiting for Hyprland" >&2
      exit 1
    fi
    sleep 5
    (( waited += 5 ))
  done
  check "Hyprland session is running" ssh_guest "pgrep -x Hyprland >/dev/null"
  check "a graphical session is active" ssh_guest "loginctl list-sessions --no-legend | grep -q seat0"
else
  log "No autologin; waiting for the SDDM greeter"
  wait_for_screen "Password" 180
  capture_console "success-sddm-greeter"
fi

# Let the compositor finish painting before the evidence shot.
sleep 10
capture_console "success-gui-login"
finish
