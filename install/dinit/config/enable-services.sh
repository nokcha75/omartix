#!/bin/bash

# Enable Artix-provided dinit services for the same user-visible facilities
# Omarchy enables on its installed systems. This runs in the target root, where
# dinit is not yet PID 1, so enablement is an explicit boot.d link rather than
# a dinitctl request.

set -euo pipefail

enable_dinit_service() {
  local service="$1"
  local definition="/etc/dinit.d/$service"

  [[ -f $definition ]] || {
    echo "Error: required dinit service is unavailable: $service" >&2
    return 1
  }

  install -d -m 0755 /etc/dinit.d/boot.d
  ln -sfn "../$service" "/etc/dinit.d/boot.d/$service"
}

# Dependencies supplied by the respective Artix *-dinit packages start
# automatically from these roots. Do not add a resolved/oomd substitute here:
# DNS is owned by NetworkManager and dinit has no systemd slice model.
install -Dm644 /usr/share/omarchy/install/artix/dinit/omarchy-plymouth-quit \
  /etc/dinit.d/omarchy-plymouth-quit
# `before = sddm` is only an ordering hint. sddm must wait for the quit
# attempt, otherwise it races Plymouth for the DRM device.
if [[ -f /etc/dinit.d/sddm ]] && ! grep -qx 'waits-for = omarchy-plymouth-quit' /etc/dinit.d/sddm; then
  printf '\nwaits-for = omarchy-plymouth-quit\n' >>/etc/dinit.d/sddm
fi
enable_dinit_service omarchy-plymouth-quit

for service in dbus logind NetworkManager bluetoothd dockerd cupsd avahi-daemon tlp sddm limine-snapper-sync zramen earlyoom; do
  enable_dinit_service "$service"
done

# Artix dinit-rc wakes getty@tty1-6 from ACTIVE_CONSOLES. SDDM needs VT1, and
# sddm-helper fails with HELPER_TTY_ERROR if agetty already owns that tty.
install -d -m 0755 /etc/dinit.d/config
cat >/etc/dinit.d/config/console.conf <<'EOF'
#!/bin/sh

# tty1 is reserved for SDDM. Recovery consoles remain on tty2-tty6.
ACTIVE_CONSOLES="/dev/tty[2-6]"
EOF
rm -f /etc/dinit.d/boot.d/getty@tty1
