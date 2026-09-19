#!/bin/bash

set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
CHECK="$ROOT/builder/check-build-environment.sh"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/bin" "$tmpdir/etc"
touch "$tmpdir/etc/artix-release"

for command_name in basestrap fstabgen artix-chroot buildiso; do
  ln -s /usr/bin/true "$tmpdir/bin/$command_name"
done
for command_name in cat grep; do
  ln -s "/usr/bin/$command_name" "$tmpdir/bin/$command_name"
done

cat > "$tmpdir/bin/pacman" <<'EOF'
#!/bin/bash
[[ $1 == -Q ]]
case "$2" in
  artix-keyring|artix-mirrorlist|artools-base|artools-iso) exit 0 ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$tmpdir/bin/pacman"

cat > "$tmpdir/bin/pacman-conf" <<'EOF'
#!/bin/bash
[[ $1 == --repo-list ]]
printf '%s\n' system world galaxy extra
EOF
chmod +x "$tmpdir/bin/pacman-conf"

PATH="$tmpdir/bin" ARTIX_RELEASE_FILE="$tmpdir/etc/artix-release" "$CHECK" \
  | grep -Fx 'Artix ISO build environment is ready.'

rm "$tmpdir/bin/buildiso"
if PATH="$tmpdir/bin" ARTIX_RELEASE_FILE="$tmpdir/etc/artix-release" "$CHECK" >"$tmpdir/output" 2>&1; then
  echo 'expected missing buildiso to fail' >&2
  exit 1
fi
grep -F 'required Artix command is unavailable: buildiso' "$tmpdir/output"
