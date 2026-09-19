#!/bin/bash

# The published source must be enough to hand the ISO work to another
# contributor. This is intentionally a source-only test: it catches a hidden
# development-tree dependency before an expensive Artix build is started.

set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
boot_builder="$ROOT/builder/build-boot-repo.sh"
readme="$ROOT/builder/README.md"

test -f "$ROOT/builder/packages/omarchy-artix-limine-mkinitcpio-hook/PKGBUILD"
grep -Fq 'omartix_pkgbuild="$omartix_source/packaging/omartix"' "$boot_builder"
grep -Fq 'OMARTIX_SRC="$omartix_source"' "$boot_builder"
if rg -n 'omartix-pkgs|omarchy-artix-runtime|omarchy-artix-settings' \
  "$ROOT/builder" "$ROOT/install-media/usr/share/omarchy-iso/artix-install.sh" \
  -g '!README.md' -g '!download-omarchy-runtime-packages.sh' | grep -q .; then
  echo 'Artix ISO source retains a retired local package-tree dependency' >&2
  exit 1
fi
grep -Fx 'artools-workspace/' "$ROOT/.gitignore"
grep -Fx 'iso-output/' "$ROOT/.gitignore"
grep -Fq 'Fresh-clone handoff' "$readme"
grep -Fq 'packaging/omartix/PKGBUILD' "$readme"
if rg -n '\bsystemctl\b' "$ROOT/test/integration" "$ROOT/test/integration.d" | grep -q .; then
  echo 'Artix dinit acceptance tooling still invokes systemctl' >&2
  exit 1
fi
