#!/bin/bash

# The installer must present encryption as an explicit choice in both storage
# flows; it must not hide the unencrypted path behind a signal shortcut.
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
configurator="$ROOT/install-media/root/configurator"

grep -Fqx 'choose_encryption() {' "$configurator"
grep -Eq '^[[:space:]]*"Encrypt disk \(recommended\)" \\$' "$configurator"
grep -Eq '^[[:space:]]*"Install without encryption"\) \|\| return 1$' "$configurator"
[[ $(grep -Fc '    choose_encryption || return 1' "$configurator") == 2 ]]
! grep -Fq 'Press Ctrl+C for unencrypted install.' "$configurator"
