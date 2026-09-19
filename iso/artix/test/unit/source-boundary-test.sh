#!/bin/bash

# A fresh Omartix clone must contain every source file used by the Artix ISO
# path. Keep this test narrow: normal target paths such as /home/$username are
# valid installer behaviour, while host/worktree paths are not.

set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
source_files=(
  "$ROOT/build.sh"
  "$ROOT"/builder/*.sh
  "$ROOT/builder/omarchy-runtime-providers"
  "$ROOT/builder/arch-extra-runtime-providers"
  "$ROOT/builder/packages/omarchy-artix-limine-mkinitcpio-hook/PKGBUILD"
  "$ROOT/install-media"
)

for path in \
  "$ROOT/build.sh" \
  "$ROOT/builder/build-iso.sh" \
  "$ROOT/builder/prepare-profile.sh" \
  "$ROOT/builder/packages/omarchy-artix-limine-mkinitcpio-hook/PKGBUILD" \
  "$ROOT/install-media/root/configurator" \
  "$ROOT/install-media/usr/share/omarchy-iso/artix-install.sh" \
  "$ROOT/test/integration"; do
  test -e "$path"
done

if rg -n '/home/chris|/home/[^$[:space:]]|/Users/|/workspace/|/projects/|omarchy-artix/lab|omartix-iso' \
  "${source_files[@]}"; then
  echo 'Artix ISO source contains a host-specific development path' >&2
  exit 1
fi

if rg -n '\.\./(omartix|omarchy|omartix-pkgs|omarchy-pkgs|omarchy-installer)|\.\./\.\./\.\./omarchy' \
  "${source_files[@]}"; then
  echo 'Artix ISO source crosses into an undeclared sibling checkout' >&2
  exit 1
fi

grep -Fx 'artools-workspace/' "$ROOT/.gitignore"
grep -Fx 'iso-output/' "$ROOT/.gitignore"
grep -Fx 'test-runs/' "$ROOT/.gitignore"
