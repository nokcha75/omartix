#!/bin/bash
# Build one or more project PKGBUILDs and publish a signed local Artix repo.

set -euo pipefail

output_dir=${1:?'usage: build-project-repo.sh OUTPUT_DIR PKGBUILD_DIR...'}
shift
(( $# > 0 )) || { printf '%s\n' 'ERROR: at least one PKGBUILD directory is required' >&2; exit 1; }

signing_key=${OMARCHY_ARTIX_GPG_KEY:?'OMARCHY_ARTIX_GPG_KEY must name an available signing key'}
repo_name=${OMARCHY_ARTIX_REPO_NAME:-omarchy-artix}
makepkg_command=${OMARCHY_ARTIX_MAKEPKG:-/usr/bin/makepkg}
retain_packages=${OMARCHY_ARTIX_RETAIN_PACKAGES:-}

# Let a terminal pinentry return the signing-key passphrase to gpg-agent.
if [[ -t 0 ]]; then
  export GPG_TTY=$(tty)
fi

gpg --list-secret-keys --with-colons "$signing_key" | grep -q '^sec:' || {
  printf 'ERROR: signing key is unavailable: %s\n' "$signing_key" >&2
  exit 1
}

mkdir -p "$output_dir"
# A package that has not changed may be retained when rebuilding this signed
# repository. This is used for the expensive ISO-only Limine native-image
# package while a changed Omartix core package is rebuilt. Retention is opt-in
# and accepts package-name prefixes only, never arbitrary paths.
retain_pattern=''
if [[ -n $retain_packages ]]; then
  IFS=',' read -r -a retained_names <<<"$retain_packages"
  for name in "${retained_names[@]}"; do
    [[ $name =~ ^[a-z0-9][a-z0-9@._+-]*$ ]] || {
      printf 'ERROR: invalid retained package name: %s\n' "$name" >&2
      exit 1
    }
    matches=("$output_dir/$name"-*.pkg.tar.zst)
    if (( ${#matches[@]} != 1 )) || [[ ! -s ${matches[0]} || ! -s ${matches[0]}.sig ]]; then
      printf 'ERROR: retained package is missing, unsigned, or ambiguous: %s\n' "$name" >&2
      exit 1
    fi
    retain_pattern+="${retain_pattern:+|}${name}-.*\\.pkg\\.tar\\.zst(\\.sig)?"
  done
fi
# A non-reuse build creates a new local repository. Remove only repository
# metadata and package archives from this explicit output directory so a
# previous split-runtime build cannot leak obsolete packages into the next ISO.
while IFS= read -r -d '' path; do
  name=${path##*/}
  [[ -n $retain_pattern && $name =~ ^($retain_pattern)$ ]] && continue
  rm -f -- "$path"
done < <(find "$output_dir" -maxdepth 1 -type f \( \
  -name '*.pkg.tar.*' -o \
  -name "$repo_name.db*" -o \
  -name "$repo_name.files*" -o \
  -name "$repo_name.gpg" -o \
  -name "$repo_name.fingerprint" \
\) -print0)
find "$output_dir" -maxdepth 1 -type l \( \
  -name "$repo_name.db" -o -name "$repo_name.files" \
\) -delete
work_dir=$(mktemp -d)
cleanup_work_dir() {
  local status=$?

  if (( status == 0 )); then
    rm -rf "$work_dir"
  else
    printf 'ERROR: preserving failed package build workspace: %s\n' "$work_dir" >&2
  fi
}
trap cleanup_work_dir EXIT

packages=()
for package_dir in "$@"; do
  [[ -f $package_dir/PKGBUILD ]] || {
    printf 'ERROR: PKGBUILD not found: %s\n' "$package_dir/PKGBUILD" >&2
    exit 1
  }

  package_work="$work_dir/$(basename "$package_dir")"
  cp -a "$package_dir/." "$package_work"
  (
    cd "$package_work"
    # PKGDEST is persistent across ISO build retries.  A previous run may
    # have produced an unsigned package before failing, so replace it here.
    # Package builds must use Artix's compiler and headers. A developer shell
    # can place a Nix compiler ahead of /usr/bin; CGO then cannot see Artix's
    # /usr/include headers even when makepkg installed every makedepend.
    /usr/bin/env -u BASH_ENV -u ENV PATH=/usr/bin:/bin CC=/usr/bin/gcc CXX=/usr/bin/g++ \
      GPGKEY="$signing_key" PKGDEST="$output_dir" "$makepkg_command" \
      --syncdeps --needed --noconfirm --cleanbuild --force --sign
  )

  built=("$output_dir"/*.pkg.tar.zst)
  for package in "${built[@]}"; do
    [[ -f $package && -f $package.sig ]] || continue
    [[ " ${packages[*]} " == *" $package "* ]] || packages+=("$package")
  done
done

(( ${#packages[@]} > 0 )) || {
  printf '%s\n' 'ERROR: no signed packages were produced' >&2
  exit 1
}

repo-add --include-sigs --sign --key "$signing_key" "$output_dir/$repo_name.db.tar.zst" "${packages[@]}"
ln -sfn "$repo_name.db.tar.zst" "$output_dir/$repo_name.db"
gpg --batch --yes --output "$output_dir/$repo_name.gpg" --export "$signing_key"
gpg --batch --with-colons --list-keys "$signing_key" | awk -F: '$1 == "fpr" { print $10; exit }' > "$output_dir/$repo_name.fingerprint"
[[ -s $output_dir/$repo_name.gpg && -s $output_dir/$repo_name.fingerprint ]] || {
  printf '%s\n' 'ERROR: could not export the public repository signing key' >&2
  exit 1
}

printf 'Built signed project package repository: %s\n' "$output_dir"
