#!/bin/bash
# Verify every Omartix base package is available from Artix, translated to an
# Artix name, supplied by the supported Arch extra compatibility layer, or
# supplied by Omarchy's published package channel.

set -euo pipefail

runtime_source=${1:?'usage: verify-runtime-package-coverage.sh RUNTIME_SOURCE'}
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
package_manifest="$runtime_source/install/omarchy-base.packages"
remote_manifest="$script_dir/omarchy-runtime-providers"
arch_extra_manifest="$script_dir/arch-extra-runtime-providers"

[[ -r $package_manifest ]] || { printf 'ERROR: runtime package manifest not found: %s\n' "$package_manifest" >&2; exit 1; }
[[ -r $remote_manifest ]] || { printf 'ERROR: Omarchy runtime provider manifest not found: %s\n' "$remote_manifest" >&2; exit 1; }
[[ -r $arch_extra_manifest ]] || { printf 'ERROR: Arch extra provider manifest not found: %s\n' "$arch_extra_manifest" >&2; exit 1; }

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

# Only public Artix repositories count. The host's custom repository must not
# hide a package that the ISO would fail to install.
pacman -Slq system world galaxy | sort -u >"$tmpdir/artix-public"
sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "$remote_manifest" | sort -u >"$tmpdir/omarchy-providers"
sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "$arch_extra_manifest" | sort -u >"$tmpdir/arch-extra-providers"

pacman -Slq extra | sort -u >"$tmpdir/arch-extra"
while IFS= read -r package; do
  grep -Fxq "$package" "$tmpdir/arch-extra" || {
    printf 'ERROR: configured Arch extra repository does not provide: %s\n' "$package" >&2
    exit 1
  }
done <"$tmpdir/arch-extra-providers"

missing=()
while IFS= read -r package; do
  case $package in
    nvim) package=neovim ;;
    vi) package=vim ;;
    bluez-tools) package=bluez-deprecated-tools ;;
    chromium) package=omarchy-chromium-bin ;;
    kernel-modules-hook) continue ;;
  esac

  if grep -Fxq "$package" "$tmpdir/artix-public" || grep -Fxq "$package" "$tmpdir/arch-extra-providers" || grep -Fxq "$package" "$tmpdir/omarchy-providers"; then
    continue
  fi

  missing+=("$package")
done < <(sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "$package_manifest")

if (( ${#missing[@]} > 0 )); then
  printf 'ERROR: Omartix base packages without an Artix, Arch-extra, or Omarchy provider:\n' >&2
  printf '  %s\n' "${missing[@]}" >&2
  exit 1
fi

printf 'Verified Artix package coverage for %s\n' "$package_manifest"
