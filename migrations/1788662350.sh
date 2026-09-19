#!/bin/bash

set -euo pipefail

# Omarchy's former repair installed systemd system-sleep hooks and a supergfxd
# systemd drop-in. Omartix deliberately does not provide that unsupported ASUS
# hybrid-GPU transition; see docs/dinit-compatibility.md for restoration terms.
echo "Leave unsupported ASUS hybrid-GPU systemd hooks inactive on dinit"
