#!/bin/bash
# Create an isolated artools workspace that overlays the Omarchy-Artix profile
# on top of the installed, Artix-owned iso-profiles common assets.

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source_profiles=${ARTIX_ISO_PROFILES_DIR:-/usr/share/artools/iso-profiles}
workspace=${1:-${WORKSPACE_DIR:-"$PWD/artools-workspace"}}
repo_root=$(cd -- "$script_dir/../../.." && pwd)
runtime_source=${2:-"$repo_root"}
destination="$workspace/iso-profiles"
profile_name=omarchy-artix

if [[ ! -d $source_profiles/common ]]; then
  printf 'ERROR: Artix iso-profiles common directory not found: %s\n' "$source_profiles/common" >&2
  exit 1
fi

if [[ ! -r $runtime_source/logo.txt ]] || [[ ! -r $runtime_source/install/provisioning/setup-form.sh ]]; then
  printf 'ERROR: Omarchy runtime source is incomplete: %s\n' "$runtime_source" >&2
  exit 1
fi

if [[ -e $destination/$profile_name ]]; then
  if [[ ${ARTIX_REPLACE_PROFILE:-0} == 1 ]]; then
    rm -rf -- "${destination:?}/${profile_name:?}"
  else
    printf 'ERROR: refusing to overwrite existing profile: %s\n' "$destination/$profile_name" >&2
    exit 1
  fi
fi

mkdir -p "$destination"
if [[ ! -e $destination/common || ${ARTIX_REPLACE_PROFILE:-0} == 1 ]]; then
  rm -rf -- "${destination:?}/common"
  cp -a "$source_profiles/common" "$destination/common"
fi

# artools' common profile still names packages removed from current Artix
# repositories.  Keep the common profile otherwise intact while using their
# maintained replacements in the generated build workspace.
common_profile="$destination/common/common.yaml"
if [[ -f $common_profile ]]; then
  sed -i \
    -e 's/^  - crda$/  - wireless-regdb/' \
    -e 's/^  - vi$/  - vim/' \
    "$common_profile"
fi

cp -a "$script_dir/profile/$profile_name" "$destination/$profile_name"

# Preserve Omarchy's wizard as the sole source of disk, encryption, locale,
# and account answers. Artix only replaces what happens after the wizard has
# emitted user_configuration.json and user_credentials.json.
overlay="$destination/$profile_name/root-overlay"
mkdir -p "$overlay/root" "$overlay/usr/local/bin" "$overlay/usr/share/omarchy-iso" "$overlay/usr/share/omarchy"
install -Dm755 "$script_dir/../install-media/root/.automated_script.sh" "$overlay/root/.automated_script.sh"
install -Dm755 "$script_dir/../install-media/root/configurator" "$overlay/root/configurator"
for command in \
  omarchy-cidata-load \
  omarchy-install-dashboard \
  omarchy-install-diagnose-media \
  omarchy-iso-cleanup-disk \
  omarchy-iso-install; do
  cp "$script_dir/../install-media/usr/local/bin/$command" "$overlay/usr/local/bin/$command"
done
install -Dm755 "$script_dir/../install-media/usr/share/omarchy-iso/artix-install.sh" "$overlay/usr/share/omarchy-iso/artix-install.sh"
cp "$script_dir/../install-media/usr/share/omarchy-iso/disk-partitioning.sh" "$overlay/usr/share/omarchy-iso/disk-partitioning.sh"
cp "$runtime_source/logo.txt" "$overlay/usr/share/omarchy/logo.txt"
cp "$runtime_source/install/provisioning/setup-form.sh" "$overlay/usr/share/omarchy-iso/setup-form.sh"
printf '%s\n' stable > "$overlay/root/omarchy_mirror"

# Omarchy keeps a verified Node archive on the ISO for first-install mise
# provisioning. Keep that contract on Artix as well: it is deliberately not a
# pacman package, because the provisioning step consumes this exact archive
# before the installed system has network-dependent tool installations.
node_version=${OMARCHY_ARTIX_NODE_VERSION:-v26.9.0}
node_filename="node-${node_version}-linux-x64.tar.gz"
node_sha=${OMARCHY_ARTIX_NODE_SHA256:-03d9104fc4f19652e74480fed11c023d75981464b7292f21a601c3f95ce7d90d}
node_dist_url=${OMARCHY_ARTIX_NODE_DIST_URL:-"https://nodejs.org/dist/$node_version"}
node_archive="$overlay/opt/packages/$node_filename"
mkdir -p "${node_archive%/*}"
curl --fail --location --silent --show-error "$node_dist_url/$node_filename" -o "$node_archive"
printf '%s  %s\n' "$node_sha" "$node_archive" | sha256sum --check --status || {
  printf 'ERROR: Node.js archive checksum verification failed: %s\n' "$node_filename" >&2
  exit 1
}

printf 'Prepared Artix dinit profile at %s\n' "$destination/$profile_name"
printf 'Run: WORKSPACE_DIR=%q sudo -E buildiso -p %s -i dinit\n' "$workspace" "$profile_name"
