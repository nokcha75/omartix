#!/bin/bash

set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
VERIFY="$ROOT/builder/verify-boot-repo.sh"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

repo="$tmpdir/repo"
mkdir -p "$repo"
for name in \
  omarchy-artix.db.tar.zst \
  omarchy-artix.db.tar.zst.sig \
  omarchy-artix.db \
  omarchy-artix.db.sig \
  offline.db \
  offline.db.sig \
  omarchy-artix.gpg \
  omarchy-artix.fingerprint \
  omarchy-artix-limine-mkinitcpio-hook-1.pkg.tar.zst \
  omarchy-artix-limine-mkinitcpio-hook-1.pkg.tar.zst.sig \
  omartix-1.pkg.tar.zst \
  omartix-1.pkg.tar.zst.sig; do
  printf x > "$repo/$name"
done

"$VERIFY" "$repo" | grep -F "Reusing signed Artix project repository: $repo"
rm "$repo/omartix-1.pkg.tar.zst.sig"
if "$VERIFY" "$repo" >"$tmpdir/output" 2>&1; then
  echo 'expected unsigned reusable package to be rejected' >&2
  exit 1
fi
grep -F 'reusable signed package is missing or ambiguous: omartix' "$tmpdir/output"
