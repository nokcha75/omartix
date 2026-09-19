#!/bin/bash
# Produce the dinit Artix live ISO from the staged Omarchy-Artix profile.

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
builder_dir=${ARTIX_BUILDER_DIR:-$script_dir}
workspace=${1:?"usage: build-iso.sh WORKSPACE_DIR OUTPUT_DIR RUNTIME_SOURCE"}
output_dir=${2:?"usage: build-iso.sh WORKSPACE_DIR OUTPUT_DIR RUNTIME_SOURCE"}
runtime_source=${3:?"usage: build-iso.sh WORKSPACE_DIR OUTPUT_DIR RUNTIME_SOURCE"}
repository_dir="$workspace/omarchy-artix-repo"
package_tmpdir=${OMARCHY_ARTIX_PACKAGE_TMPDIR:-"$workspace/package-tmp"}
buildiso_command=${ARTIX_BUILDISO_COMMAND:-/usr/bin/buildiso}
sudo_command=${ARTIX_SUDO_COMMAND:-/usr/bin/sudo}
artix_mirror=${OMARCHY_ARTIX_MIRROR:-https://mirror1.artixlinux.org/repos}
reuse_boot_repo=${OMARCHY_ARTIX_REUSE_BOOT_REPO:-0}
artools_config_home="$workspace/artools-config"
artools_pacman_conf="$artools_config_home/artools/pacman.conf.d/iso-x86_64.conf"

"$builder_dir/check-build-environment.sh"
"$builder_dir/verify-runtime-package-coverage.sh" "$runtime_source"
# Downloading published runtime packages requires root pacman access. Verify
# that authentication before compiling the ISO-owned packages, so a missing
# sudo credential cannot waste a lengthy native-image build.
if (( EUID != 0 )); then
  "$sudo_command" -v
fi
if [[ $reuse_boot_repo == 1 ]]; then
  "$builder_dir/verify-boot-repo.sh" "$repository_dir"
else
  # Large source archives (notably GraalVM) are unpacked by makepkg. Keep
  # that transient build tree beside the workspace rather than on /tmp,
  # which is commonly a small tmpfs on developer machines.
  mkdir -p "$package_tmpdir"
  TMPDIR="$package_tmpdir" \
    "$builder_dir/build-boot-repo.sh" "$repository_dir" "$runtime_source"
  "$builder_dir/download-omarchy-runtime-packages.sh" "$repository_dir"
fi
ARTIX_REPLACE_PROFILE=1 "$builder_dir/prepare-profile.sh" "$workspace" "$runtime_source"
"$builder_dir/stage-boot-repo.sh" "$repository_dir" "$workspace"

mkdir -p "$output_dir"
# Do not let pacman round-robin across a long mirror list while rootfs is being
# built. A repository database from one mirror paired with a package from a
# mirror that is still syncing produces a valid Artix package with a mismatched
# detached signature. Keep a build-local copy of artools' config and pin all
# Artix repositories to one HTTPS mirror instead.
mkdir -p "$(dirname "$artools_pacman_conf")"
cp /usr/share/artools/pacman.conf.d/iso-x86_64.conf "$artools_pacman_conf"
/usr/bin/sed -i 's|^Include = /etc/pacman.d/mirrorlist$|Server = '"${artix_mirror%/}"'/$repo/os/$arch|' "$artools_pacman_conf"
[[ $(/usr/bin/grep -Fc "Server = ${artix_mirror%/}/\$repo/os/\$arch" "$artools_pacman_conf") == 3 ]] || {
  printf 'ERROR: failed to pin Artix build mirror in %s\n' "$artools_pacman_conf" >&2
  exit 1
}

# artools requires the Go-based Artix yq, whose `-P` option is incompatible
# with the jq wrapper that Nix may place first in PATH. Use the Artix entry
# point and a closed system PATH. buildiso normally re-execs itself through
# sudo, which discards that PATH; elevate this final command ourselves so its
# initial process is already root. Clear shell startup hooks as well.
buildiso_environment=(
  /usr/bin/env -u BASH_ENV -u ENV PATH=/usr/bin:/bin
  "XDG_CONFIG_HOME=$artools_config_home" "WORKSPACE_DIR=$workspace" "ISO_POOL=$output_dir"
  "$buildiso_command" -p omarchy-artix -i dinit
)
if (( EUID == 0 )); then
  exec "${buildiso_environment[@]}"
else
  exec "$sudo_command" "${buildiso_environment[@]}"
fi
