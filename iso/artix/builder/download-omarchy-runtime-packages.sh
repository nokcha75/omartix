#!/bin/bash
# Add published Omarchy and audited Arch-extra application packages to the
# ISO-local repository.
#
# This is deliberately a binary download path. PKGBUILDs for those applications
# are not part of an ordinary Omartix ISO build; local source builds are a
# separate developer workflow, just as they are for upstream Omarchy ISO.

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
output_dir=${1:?"usage: download-omarchy-runtime-packages.sh OUTPUT_DIR"}
omarchy_manifest="$script_dir/omarchy-runtime-providers"
arch_extra_manifest="$script_dir/arch-extra-runtime-providers"
signing_key=${OMARCHY_ARTIX_GPG_KEY:?'OMARCHY_ARTIX_GPG_KEY must name an available signing key'}
repo_name=${OMARCHY_ARTIX_REPO_NAME:-omarchy-artix}
channel=${OMARCHY_CHANNEL:-stable}
artix_mirror=${OMARCHY_ARTIX_MIRROR:-https://mirror1.artixlinux.org/repos}
sudo_command=${ARTIX_SUDO_COMMAND:-/usr/bin/sudo}
# The resolved package closure is several GiB. Keep it in the ISO build
# workspace (normally on the developer's disk), never the RAM-backed /tmp.
work_parent=${OMARCHY_ARTIX_DOWNLOAD_TMPDIR:-$output_dir}

[[ -r $omarchy_manifest ]] || { printf 'ERROR: Omarchy runtime provider manifest not found: %s\n' "$omarchy_manifest" >&2; exit 1; }
[[ -r $arch_extra_manifest ]] || { printf 'ERROR: Arch extra provider manifest not found: %s\n' "$arch_extra_manifest" >&2; exit 1; }
gpg --list-secret-keys --with-colons "$signing_key" | grep -q '^sec:' || {
  printf 'ERROR: signing key is unavailable: %s\n' "$signing_key" >&2
  exit 1
}
if [[ -t 0 ]]; then
  GPG_TTY=$(tty)
  export GPG_TTY
fi

mapfile -t packages < <(
  sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "$omarchy_manifest" "$arch_extra_manifest" |
    sort -u
)
(( ${#packages[@]} > 0 )) || { printf '%s\n' 'ERROR: Omarchy runtime provider manifest is empty' >&2; exit 1; }

mkdir -p "$output_dir" "$work_parent"
work_dir=$(mktemp -d "$work_parent/.omarchy-runtime-download.XXXXXX")
cleanup() {
  # pacman creates the synced DB as root. Remove this exact build-owned
  # temporary directory through the same narrowly scoped elevation used below.
  "$sudo_command" rm -rf "$work_dir"
}
trap cleanup EXIT
config="$work_dir/pacman.conf"

cat >"$config" <<EOF
[options]
Architecture = auto
SigLevel = Required DatabaseOptional

[system]
Server = ${artix_mirror%/}/\$repo/os/\$arch
[world]
Server = ${artix_mirror%/}/\$repo/os/\$arch
[galaxy]
Server = ${artix_mirror%/}/\$repo/os/\$arch

[extra]
Include = /etc/pacman.d/mirrorlist-arch

[omarchy]
# Omarchy does not publish a keyring consumable by Artix pacman. These archives
# are copied into a local repository whose database is signed below with the
# Omartix build key, and the finished ISO is integrity-protected. Avoid an
# unreliable public-keyserver lookup while fetching the upstream artifacts.
SigLevel = Never
Server = https://pkgs.omarchy.org/${channel}/\$arch
EOF

mkdir -p "$work_dir/db" "$work_dir/cache"

# A previous interrupted download can leave truncated archives in the project
# repository. Keep only the two Omartix-owned build artifacts; every other
# archive is a disposable remote cache and must be re-resolved for this ISO.
"$sudo_command" find "$output_dir" -maxdepth 1 -type f \
  ! -name 'omarchy-artix-limine-mkinitcpio-hook-*.pkg.tar.*' \
  ! -name 'omartix-*.pkg.tar.*' \
  -name '*.pkg.tar.*' -delete
# Syncing a package database is deliberately privileged in pacman. Limit sudo
# to this download transaction; local repository metadata is still signed below
# by the invoking developer's Omartix key.
"$sudo_command" pacman-key --populate artix archlinux
"$sudo_command" pacman --config "$config" --noconfirm -Syw --needed \
  --cachedir "$work_dir/cache" --dbpath "$work_dir/db" "${packages[@]}"

# pacman writes cached archives as root. The following repo-add invocation
# needs to use the invoking user's GPG agent, so return only package artifacts
# to that user rather than running the signing operation under sudo.
"$sudo_command" chown "$(id -u):$(id -g)" "$work_dir/cache"/*.pkg.tar.*
mv "$work_dir/cache"/*.pkg.tar.* "$output_dir/"

# The local database is signed by Omartix. Keep the packages from the Omarchy
# channel unsigned in this *local* mirror: their checksum is protected by that
# signed database and by the ISO image integrity check, and installation does
# not depend on importing Omarchy's package signing key.
while IFS= read -r filename; do
  rm -f "$output_dir/$filename.sig"
done < <(pacman --config "$config" --dbpath "$work_dir/db" -S --print --print-format '%f' "${packages[@]}")

packages_in_repo=("$output_dir"/*.pkg.tar.zst)
(( ${#packages_in_repo[@]} > 0 )) || { printf '%s\n' 'ERROR: no packages available for the ISO-local repository' >&2; exit 1; }
# repo-add updates the database archive but does not reliably replace an
# existing detached signature. Remove only build-owned database metadata so
# the freshly resolved package set and its signature always match. Sign just
# the database explicitly afterwards: repo-add otherwise asks for the key once
# per database artifact, which can leave the required package database unsigned
# while a nonessential .files signature succeeds.
rm -f "$output_dir/$repo_name.db" "$output_dir/$repo_name.db.sig" \
  "$output_dir/$repo_name.db.tar.zst" "$output_dir/$repo_name.db.tar.zst.sig" \
  "$output_dir/$repo_name.db.tar.zst.old" "$output_dir/$repo_name.db.tar.zst.old.sig"
repo-add --include-sigs "$output_dir/$repo_name.db.tar.zst" "${packages_in_repo[@]}"
gpg --detach-sign --local-user "$signing_key" \
  --output "$output_dir/$repo_name.db.tar.zst.sig" "$output_dir/$repo_name.db.tar.zst"
ln -sfn "$repo_name.db.tar.zst" "$output_dir/$repo_name.db"
# Pacman requests the signature through the short database alias, too.
ln -sfn "$repo_name.db.tar.zst.sig" "$output_dir/$repo_name.db.sig"
# Omarchy's first-install scripts retain the upstream [offline] repository
# contract. Point that name at the same signed local database rather than
# making the dinit port maintain a second, duplicate package index.
ln -sfn "$repo_name.db.tar.zst" "$output_dir/offline.db"
ln -sfn "$repo_name.db.tar.zst.sig" "$output_dir/offline.db.sig"

printf 'Downloaded published Omarchy runtime packages into %s\n' "$output_dir"
