#!/bin/bash
# Refuse to run the Artix ISO backend from an Arch/archiso environment.

set -euo pipefail

release_file=${ARTIX_RELEASE_FILE:-/etc/artix-release}
required_commands=(basestrap fstabgen artix-chroot buildiso)
required_packages=(artix-keyring artix-mirrorlist artools-base artools-iso)
required_repositories=(system world galaxy)
failures=0

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  failures=1
}

[[ -r $release_file ]] || fail "Artix release marker not found: $release_file"

for command_name in "${required_commands[@]}"; do
  command -v "$command_name" >/dev/null 2>&1 || fail "required Artix command is unavailable: $command_name"
done

for package_name in "${required_packages[@]}"; do
  pacman -Q "$package_name" >/dev/null 2>&1 || fail "required Artix package is not installed: $package_name"
done

if command -v pacman-conf >/dev/null 2>&1; then
  configured_repositories=$(pacman-conf --repo-list 2>/dev/null || true)
  for repository_name in "${required_repositories[@]}"; do
    grep -Fx "$repository_name" <<<"$configured_repositories" >/dev/null || \
      fail "required Artix repository is not configured: [$repository_name]"
  done
else
  fail 'required pacman command is unavailable: pacman-conf'
fi

if (( failures )); then
  cat >&2 <<'EOF'

The Artix backend requires an Artix build environment. Install and initialize
artix-keyring, artix-mirrorlist, artools-base, and artools-iso from Artix, then
run this check again. Do not bypass package signature verification.
EOF
  exit 1
fi

printf '%s\n' 'Artix ISO build environment is ready.'
