#!/bin/bash

set -euo pipefail

echo "Keep zram managed by zramen"

# Migration 1784961000 has already installed and configured Artix's zramen
# dinit service. The upstream follow-up only retired the former generator
# files; those are not part of Omartix's active zram path. Do not remove legacy
# files from an existing machine: they may document an administrator's old
# policy, and deleting them cannot improve the running zramen configuration.
