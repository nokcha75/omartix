#!/bin/bash

set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
STAGE="$ROOT/builder/stage-boot-repo.sh"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

repo="$tmpdir/repo"
workspace="$tmpdir/workspace"
mkdir -p "$repo" "$workspace/iso-profiles/omarchy-artix/root-overlay"
for name in omarchy-artix.db.tar.zst omarchy-artix.db.tar.zst.sig omarchy-artix.db omarchy-artix.db.sig offline.db offline.db.sig omarchy-artix.gpg omarchy-artix.fingerprint omarchy-artix-limine-mkinitcpio-hook-1.pkg.tar.zst omarchy-artix-limine-mkinitcpio-hook-1.pkg.tar.zst.sig; do
  printf x > "$repo/$name"
done

"$STAGE" "$repo" "$workspace" | grep -F 'Staged signed Artix package repository'
config="$workspace/iso-profiles/omarchy-artix/root-overlay/usr/share/omarchy-iso/artix-repo/pacman.conf"
grep -Fx 'SigLevel = Optional DatabaseRequired' "$config"
grep -Fx 'Server = file:///usr/share/omarchy-iso/artix-repo' "$config"
