#!/bin/bash

set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
BUILD="$ROOT/builder/build-boot-repo.sh"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/bin" "$tmpdir/output" "$tmpdir/omartix/packaging/omartix"
touch "$tmpdir/omartix/packaging/omartix/PKGBUILD"
printf '%s\n' '#!/bin/bash' 'if [[ $* == *--list-secret-keys* ]]; then printf "sec:u:1:0:0000000000000000::::::::\n"; elif [[ $* == *--with-colons* ]]; then printf "fpr:::::::::0000000000000000:\n"; elif [[ $* == *--export* ]]; then for ((i=1; i<=$#; i++)); do [[ ${!i} == --output ]] && { next=$((i+1)); printf public-key > "${!next}"; }; done; fi; true' > "$tmpdir/bin/gpg"
printf '%s\n' '#!/bin/bash' 'name=$(basename "$PWD"); printf package > "$PKGDEST/${name}-1-1-x86_64.pkg.tar.zst"; printf signature > "$PKGDEST/${name}-1-1-x86_64.pkg.tar.zst.sig"' > "$tmpdir/bin/makepkg"
printf '%s\n' '#!/bin/bash' 'for arg in "$@"; do [[ $arg == *.db.tar.zst ]] && touch "$arg" "$arg.sig"; done; true' > "$tmpdir/bin/repo-add"
chmod +x "$tmpdir/bin/gpg" "$tmpdir/bin/makepkg" "$tmpdir/bin/repo-add"

PATH="$tmpdir/bin:$PATH" OMARCHY_ARTIX_MAKEPKG="$tmpdir/bin/makepkg" OMARCHY_ARTIX_GPG_KEY=0000000000000000 "$BUILD" "$tmpdir/output" "$tmpdir/omartix" | grep -F "Built signed project package repository: $tmpdir/output"
arch_extra_manifest="$ROOT/builder/arch-extra-runtime-providers"
test -r "$arch_extra_manifest"
grep -Fq 'PATH=/usr/bin:/bin CC=/usr/bin/gcc CXX=/usr/bin/g++' "$ROOT/builder/build-project-repo.sh"
for package in dua-cli lazydocker moonlight-qt nautilus-python obsidian pinta; do
  grep -Fxq "$package" "$arch_extra_manifest"
done
test -f "$tmpdir/output/omarchy-artix.db.tar.zst"
test -f "$tmpdir/output/omarchy-artix.db.tar.zst.sig"
test -f "$tmpdir/output/omartix-1-1-x86_64.pkg.tar.zst"
test -f "$tmpdir/output/omartix-1-1-x86_64.pkg.tar.zst.sig"
test -L "$tmpdir/output/omarchy-artix.db"
test -s "$tmpdir/output/omarchy-artix.gpg"
test "$(< "$tmpdir/output/omarchy-artix.fingerprint")" = 0000000000000000

PATH="$tmpdir/bin:$PATH" OMARCHY_ARTIX_MAKEPKG="$tmpdir/bin/makepkg" OMARCHY_ARTIX_GPG_KEY=0000000000000000 OMARCHY_ARTIX_REUSE_LIMINE_PACKAGE=1 "$BUILD" "$tmpdir/output" "$tmpdir/omartix" | grep -F "Built signed project package repository: $tmpdir/output"
