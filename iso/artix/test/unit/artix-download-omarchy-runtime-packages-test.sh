#!/bin/bash

set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
DOWNLOAD="$ROOT/builder/download-omarchy-runtime-packages.sh"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/bin" "$tmpdir/output"
printf '%s\n' '#!/bin/bash' \
  'if [[ $* == *--list-secret-keys* ]]; then printf "sec:u:1:0:0000000000000000::::::::\n"; exit; fi' \
  'if [[ $* == *--detach-sign* ]]; then for ((i=1; i<=$#; i++)); do [[ ${!i} == --output ]] && { next=$((i+1)); touch "${!next}"; exit; }; done; fi' \
  > "$tmpdir/bin/gpg"
printf '%s\n' '#!/bin/bash' '
cachedir=""
for ((i=1; i<=$#; i++)); do
  [[ ${!i} == --cachedir ]] && { next=$((i+1)); cachedir=${!next}; }
done
if [[ $* == *--print-format* ]]; then
  printf "%s\n" aether-1-1-x86_64.pkg.tar.zst
else
  mkdir -p "$cachedir"
  touch "$cachedir/aether-1-1-x86_64.pkg.tar.zst" "$cachedir/aether-1-1-x86_64.pkg.tar.zst.sig"
fi' > "$tmpdir/bin/pacman"
printf '%s\n' '#!/bin/bash' 'for arg in "$@"; do [[ $arg == *.db.tar.zst ]] && touch "$arg"; done' 'true' > "$tmpdir/bin/repo-add"
printf '%s\n' '#!/bin/bash' 'true' > "$tmpdir/bin/pacman-key"
printf '%s\n' '#!/bin/bash' 'exec "$@"' > "$tmpdir/bin/sudo"
chmod +x "$tmpdir/bin/gpg" "$tmpdir/bin/pacman" "$tmpdir/bin/repo-add" "$tmpdir/bin/pacman-key" "$tmpdir/bin/sudo"

PATH="$tmpdir/bin:$PATH" ARTIX_SUDO_COMMAND="$tmpdir/bin/sudo" OMARCHY_ARTIX_GPG_KEY=0000000000000000 "$DOWNLOAD" "$tmpdir/output" | grep -F "Downloaded published Omarchy runtime packages into $tmpdir/output"
test -f "$tmpdir/output/aether-1-1-x86_64.pkg.tar.zst"
test ! -e "$tmpdir/output/aether-1-1-x86_64.pkg.tar.zst.sig"
test -f "$tmpdir/output/omarchy-artix.db.tar.zst"
test -f "$tmpdir/output/omarchy-artix.db.tar.zst.sig"
test -L "$tmpdir/output/omarchy-artix.db"
test -L "$tmpdir/output/omarchy-artix.db.sig"
test -L "$tmpdir/output/offline.db"
test -L "$tmpdir/output/offline.db.sig"
grep -Fq 'Server = https://pkgs.omarchy.org/${channel}/\$arch' "$DOWNLOAD"
grep -Fq 'SigLevel = Never' "$DOWNLOAD"
grep -Fq 'omarchy-runtime-providers' "$DOWNLOAD"
grep -Fq 'arch-extra-runtime-providers' "$DOWNLOAD"
grep -Fq '"$omarchy_manifest" "$arch_extra_manifest"' "$DOWNLOAD"
grep -Fq '"$sudo_command" pacman' "$DOWNLOAD"
grep -Fq 'pacman-key --populate artix archlinux' "$DOWNLOAD"
grep -Fq '"$work_dir/cache"' "$DOWNLOAD"
grep -Fq 'freshly resolved package set and its signature always match' "$DOWNLOAD"
grep -Fq 'gpg --detach-sign --local-user "$signing_key"' "$DOWNLOAD"
