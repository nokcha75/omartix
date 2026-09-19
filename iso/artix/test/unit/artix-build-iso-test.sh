#!/bin/bash

set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
BUILD="$ROOT/builder/build-iso.sh"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/bin" "$tmpdir/runtime"
touch "$tmpdir/runtime/logo.txt"
mkdir -p "$tmpdir/runtime/install/provisioning"
touch "$tmpdir/runtime/install/provisioning/setup-form.sh"

for tool in check-build-environment.sh verify-runtime-package-coverage.sh build-boot-repo.sh download-omarchy-runtime-packages.sh verify-boot-repo.sh prepare-profile.sh stage-boot-repo.sh; do
  printf '%s\n' '#!/bin/bash' "printf '%s\\n' '$tool'" > "$tmpdir/bin/$tool"
  chmod +x "$tmpdir/bin/$tool"
done
printf '%s\n' '#!/bin/bash' 'test "$1" = "$EXPECTED_BOOT_REPOSITORY"' 'test "$2" = "$EXPECTED_RUNTIME_SOURCE"' 'test "$TMPDIR" = "$EXPECTED_PACKAGE_TMPDIR"' 'printf "%s\\n" build-boot-repo.sh' > "$tmpdir/bin/build-boot-repo.sh"
chmod +x "$tmpdir/bin/build-boot-repo.sh"
printf '%s\n' '#!/bin/bash' 'test "$ARTIX_REPLACE_PROFILE" = 1; printf "%s\\n" prepare-profile.sh' > "$tmpdir/bin/prepare-profile.sh"
chmod +x "$tmpdir/bin/prepare-profile.sh"
printf '%s\n' '#!/bin/bash' 'test "$XDG_CONFIG_HOME" = "$EXPECTED_ARTOOLS_CONFIG_HOME"' 'grep -Fx "Server = https://mirror1.artixlinux.org/repos/\$repo/os/\$arch" "$XDG_CONFIG_HOME/artools/pacman.conf.d/iso-x86_64.conf" >/dev/null' 'printf "buildiso %s\n" "$*"' > "$tmpdir/bin/buildiso"
chmod +x "$tmpdir/bin/buildiso"
printf '%s\n' '#!/bin/bash' '[[ ${1:-} == -v ]] && exit 0; exec "$@"' > "$tmpdir/bin/sudo"
chmod +x "$tmpdir/bin/sudo"

ARTIX_BUILDER_DIR="$tmpdir/bin" ARTIX_BUILDISO_COMMAND="$tmpdir/bin/buildiso" ARTIX_SUDO_COMMAND="$tmpdir/bin/sudo" PATH="$tmpdir/bin:$PATH" EXPECTED_RUNTIME_SOURCE="$tmpdir/runtime" EXPECTED_BOOT_REPOSITORY="$tmpdir/workspace/omarchy-artix-repo" EXPECTED_PACKAGE_TMPDIR="$tmpdir/workspace/package-tmp" EXPECTED_ARTOOLS_CONFIG_HOME="$tmpdir/workspace/artools-config" \
  "$BUILD" "$tmpdir/workspace" "$tmpdir/output" "$tmpdir/runtime" > "$tmpdir/output.log"
grep -Fx 'check-build-environment.sh' "$tmpdir/output.log"
grep -Fx 'verify-runtime-package-coverage.sh' "$tmpdir/output.log"
grep -Fx 'build-boot-repo.sh' "$tmpdir/output.log"
grep -Fx 'download-omarchy-runtime-packages.sh' "$tmpdir/output.log"
grep -Fx 'prepare-profile.sh' "$tmpdir/output.log"
grep -Fx 'stage-boot-repo.sh' "$tmpdir/output.log"
grep -Fx 'buildiso -p omarchy-artix -i dinit' "$tmpdir/output.log"
grep -F 'exec "$sudo_command" "${buildiso_environment[@]}"' "$BUILD"
grep -F '"$sudo_command" -v' "$BUILD"
grep -F 'artix_mirror=${OMARCHY_ARTIX_MIRROR:-https://mirror1.artixlinux.org/repos}' "$BUILD"

ARTIX_BUILDER_DIR="$tmpdir/bin" ARTIX_BUILDISO_COMMAND="$tmpdir/bin/buildiso" ARTIX_SUDO_COMMAND="$tmpdir/bin/sudo" PATH="$tmpdir/bin:$PATH" EXPECTED_RUNTIME_SOURCE="$tmpdir/runtime" EXPECTED_ARTOOLS_CONFIG_HOME="$tmpdir/workspace/artools-config" OMARCHY_ARTIX_REUSE_BOOT_REPO=1 \
  "$BUILD" "$tmpdir/workspace" "$tmpdir/output" "$tmpdir/runtime" > "$tmpdir/reuse.log"
grep -Fx 'verify-boot-repo.sh' "$tmpdir/reuse.log"
if grep -Fx 'build-boot-repo.sh' "$tmpdir/reuse.log"; then
  echo 'incremental build unexpectedly rebuilt project packages' >&2
  exit 1
fi
