#!/bin/bash
# Verify that a previously-built local repository is complete enough for a
# profile-only ISO rebuild. pacman still verifies these signatures on the ISO;
# this gate prevents an incremental build from silently staging unsigned files.

set -euo pipefail

repo_dir=${1:?'usage: verify-boot-repo.sh REPOSITORY_DIR'}
repo_name=${OMARCHY_ARTIX_REPO_NAME:-omarchy-artix}

required=(
  "$repo_dir/$repo_name.db.tar.zst"
  "$repo_dir/$repo_name.db.tar.zst.sig"
  "$repo_dir/$repo_name.db"
  "$repo_dir/$repo_name.db.sig"
  "$repo_dir/offline.db"
  "$repo_dir/offline.db.sig"
  "$repo_dir/$repo_name.gpg"
  "$repo_dir/$repo_name.fingerprint"
)

for path in "${required[@]}"; do
  [[ -s $path ]] || {
    printf 'ERROR: reusable Artix repository asset is missing or empty: %s\n' "$path" >&2
    exit 1
  }
done

for package in omarchy-artix-limine-mkinitcpio-hook omartix; do
  matches=("$repo_dir/$package"-*.pkg.tar.zst)
  if (( ${#matches[@]} != 1 )) || [[ ! -s ${matches[0]} || ! -s ${matches[0]}.sig ]]; then
    printf 'ERROR: reusable signed package is missing or ambiguous: %s\n' "$package" >&2
    exit 1
  fi
done

printf 'Reusing signed Artix project repository: %s\n' "$repo_dir"
