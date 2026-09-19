#!/bin/bash
# Build only Omartix-owned packages in the signed local project repository.
#
# Omarchy applications are intentionally not compiled here. The production ISO
# fetches their published artifacts from the selected Omarchy channel in a
# separate step, matching Omarchy ISO's non-local-source behaviour.

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
output_dir=${1:?"usage: build-boot-repo.sh OUTPUT_DIR OMARTIX_SOURCE"}
omartix_source=${2:?"usage: build-boot-repo.sh OUTPUT_DIR OMARTIX_SOURCE"}
pkgbuild_source="$script_dir/packages/omarchy-artix-limine-mkinitcpio-hook"
omartix_pkgbuild="$omartix_source/packaging/omartix"
reuse_limine=${OMARCHY_ARTIX_REUSE_LIMINE_PACKAGE:-0}

[[ -f $pkgbuild_source/PKGBUILD ]] || { printf 'ERROR: Artix Limine PKGBUILD not found: %s\n' "$pkgbuild_source/PKGBUILD" >&2; exit 1; }
[[ -f $omartix_pkgbuild/PKGBUILD ]] || { printf 'ERROR: Omartix package recipe not found: %s\n' "$omartix_pkgbuild/PKGBUILD" >&2; exit 1; }

# The core package is built directly from the explicitly supplied Omartix
# checkout. Never infer a sibling development tree: a fresh clone must be
# sufficient to reproduce the ISO package repository.
if [[ $reuse_limine == 1 ]]; then
  # The Limine hook is expensive to compile but independent of the Omartix
  # checkout. Keep one already-signed archive, rebuild omartix, and sign a
  # fresh repository database containing both packages.
  OMARCHY_ARTIX_RETAIN_PACKAGES=omarchy-artix-limine-mkinitcpio-hook \
    OMARTIX_SRC="$omartix_source" exec "$script_dir/build-project-repo.sh" "$output_dir" "$omartix_pkgbuild"
fi

OMARTIX_SRC="$omartix_source" exec "$script_dir/build-project-repo.sh" "$output_dir" "$pkgbuild_source" "$omartix_pkgbuild"
