#!/bin/bash

set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
BUILD="$ROOT/builder/build-project-repo.sh"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/bin" "$tmpdir/output" "$tmpdir/one" "$tmpdir/two"
touch "$tmpdir/one/PKGBUILD" "$tmpdir/two/PKGBUILD"
touch "$tmpdir/output/omarchy-artix-runtime-legacy.pkg.tar.zst"

printf '%s\n' '#!/bin/bash' 'if [[ $* == *--list-secret-keys* ]]; then printf "sec:u:1:0:0000000000000000::::::::\n"; elif [[ $* == *--with-colons* ]]; then printf "fpr:::::::::0000000000000000:\n"; elif [[ $* == *--export* ]]; then for ((i=1; i<=$#; i++)); do [[ ${!i} == --output ]] && { next=$((i+1)); printf public-key > "${!next}"; }; done; fi; true' > "$tmpdir/bin/gpg"
printf '%s\n' '#!/bin/bash' 'package=$(basename "$PWD"); touch "$PKGDEST/$package-1-1-x86_64.pkg.tar.zst" "$PKGDEST/$package-1-1-x86_64.pkg.tar.zst.sig"' > "$tmpdir/bin/makepkg"
printf '%s\n' '#!/bin/bash' 'for arg in "$@"; do [[ $arg == *.db.tar.zst ]] && touch "$arg" "$arg.sig"; done; true' > "$tmpdir/bin/repo-add"
chmod +x "$tmpdir/bin/gpg" "$tmpdir/bin/makepkg" "$tmpdir/bin/repo-add"

PATH="$tmpdir/bin:$PATH" OMARCHY_ARTIX_MAKEPKG="$tmpdir/bin/makepkg" OMARCHY_ARTIX_GPG_KEY=0000000000000000 "$BUILD" "$tmpdir/output" "$tmpdir/one" "$tmpdir/two" | grep -F "Built signed project package repository: $tmpdir/output"
test -f "$tmpdir/output/one-1-1-x86_64.pkg.tar.zst"
test -f "$tmpdir/output/two-1-1-x86_64.pkg.tar.zst"
test -f "$tmpdir/output/omarchy-artix.db.tar.zst"
test ! -e "$tmpdir/output/omarchy-artix-runtime-legacy.pkg.tar.zst"
grep -F 'export GPG_TTY=$(tty)' "$BUILD"
grep -F -- '--syncdeps --needed --noconfirm --cleanbuild --force --sign' "$BUILD"

failure_output=$(PATH="$tmpdir/bin:$PATH" OMARCHY_ARTIX_MAKEPKG="$tmpdir/bin/makepkg" OMARCHY_ARTIX_GPG_KEY=0000000000000000 "$BUILD" "$tmpdir/output" "$tmpdir/missing" 2>&1 || true)
grep -F 'ERROR: preserving failed package build workspace:' <<< "$failure_output"
