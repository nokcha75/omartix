#!/bin/bash

set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

mkdir -p "$tmp_dir/bin"
for backend in tlpctl powerprofilesctl; do
  cat >"$tmp_dir/bin/$backend" <<EOF
#!/bin/bash
printf '$backend %s\\n' "\$*" >>"\$OMARCHY_POWERPROFILES_LOG"
EOF
  chmod +x "$tmp_dir/bin/$backend"
done

export PATH="$tmp_dir/bin:$ROOT/bin:$PATH"
export OMARCHY_POWERPROFILES_LOG="$tmp_dir/calls"
OMARCHY_POWERPROFILES_BACKEND=tlpctl omarchy-powerprofilesctl get
OMARCHY_POWERPROFILES_BACKEND=powerprofilesctl omarchy-powerprofilesctl set balanced

[[ $(<"$OMARCHY_POWERPROFILES_LOG") == $'tlpctl get\npowerprofilesctl set balanced' ]] ||
  { echo "unexpected power backend calls" >&2; exit 1; }
if OMARCHY_POWERPROFILES_BACKEND=invalid omarchy-powerprofilesctl get 2>/dev/null; then
  echo "invalid backend unexpectedly succeeded" >&2
  exit 1
fi

rg -F 'command: ["omarchy-powerprofilesctl", "get"]' "$ROOT/shell/plugins/services/battery/Service.qml"
rg -F 'current=$(omarchy-powerprofilesctl get 2>/dev/null)' "$ROOT/shell/plugins/menu/Menu.qml"
