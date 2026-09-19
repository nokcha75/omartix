#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

packaged_defaults="$ROOT/install/artix/omarchy-defaults.conf"

grep -Fq 'KERNEL_CMDLINE[default]+=" initramfs_async=0"' "$packaged_defaults" ||
  fail "the packaged Limine defaults still unpack the initramfs synchronously"
pass "packaged Limine defaults keep Plymouth alive at the LUKS prompt"

grep -Fxq 'BOOT_ORDER="*, *fallback, Snapshots"' "$packaged_defaults" ||
  fail "packaged Limine defaults keep the Artix kernel first"
pass "packaged Limine defaults keep the Artix kernel first"
