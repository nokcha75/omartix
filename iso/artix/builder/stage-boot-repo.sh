#!/bin/bash
# Stage a signed project package repo into an artools profile overlay.

set -euo pipefail

repo_dir=${1:?"usage: stage-boot-repo.sh REPOSITORY_DIR WORKSPACE_DIR"}
workspace=${2:?"usage: stage-boot-repo.sh REPOSITORY_DIR WORKSPACE_DIR"}
profile_root="$workspace/iso-profiles/omarchy-artix/root-overlay"
destination="$profile_root/usr/share/omarchy-iso/artix-repo"

required=(omarchy-artix.db.tar.zst omarchy-artix.db.tar.zst.sig omarchy-artix.db omarchy-artix.db.sig offline.db offline.db.sig omarchy-artix.gpg omarchy-artix.fingerprint)
for name in "${required[@]}"; do
  [[ -s $repo_dir/$name ]] || { printf 'ERROR: signed repository file missing: %s\n' "$repo_dir/$name" >&2; exit 1; }
done
packages=("$repo_dir"/*.pkg.tar.zst)
(( ${#packages[@]} > 0 )) || {
  printf '%s\n' 'ERROR: signed project package repository contains no packages' >&2; exit 1;
}
for package in "${packages[@]}"; do
  [[ -s $package ]] || {
    printf 'ERROR: package is empty: %s\n' "$package" >&2
    exit 1
  }
done
[[ -d $profile_root ]] || { printf 'ERROR: Artix profile has not been prepared: %s\n' "$profile_root" >&2; exit 1; }

mkdir -p "$destination"
cp -a "$repo_dir/." "$destination/"
cat > "$destination/pacman.conf" <<'EOF'
Include = /etc/pacman.conf

[omarchy-artix]
# The repository database is signed by the local Omartix build key. Published
# Omarchy packages keep their original payload checksum in that signed database
# but are not re-signed, so package signatures must remain optional here.
SigLevel = Optional DatabaseRequired
Server = file:///usr/share/omarchy-iso/artix-repo
EOF
printf 'Staged signed Artix package repository at %s\n' "$destination"
