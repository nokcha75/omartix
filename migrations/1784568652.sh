#!/bin/bash

echo "Keep the desktop independent of network connection timing"

# systemd's NetworkManager-wait-online.service could pull network-online into
# graphical boot and delay the desktop until DHCP or Wi-Fi association finished.
# Artix dinit has no NetworkManager-specific wait service; its generic
# network-online.target only runs when an enabled service explicitly depends on
# it. Omartix enables none, so the desired no-wait behavior is already native.
