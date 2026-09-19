#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

skip_file="$ROOT/migrations/artix-skip.txt"
grep -Fxq '1789325478.sh' "$skip_file" || fail "linux-omarchy kernel migration is on the Artix skip list"
grep -Fxq '1789444024.sh' "$skip_file" || fail "Omarchy/T2 header migration is on the Artix skip list"
grep -F 'linux-omarchy' "$ROOT/migrations/1789325478.sh" >/dev/null ||
  fail "the skipped kernel migration keeps the upstream linux-omarchy script"

scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
export OMARCHY_PATH="$ROOT"
export OMARCHY_MIGRATION_STATE="$scratch/state"
mkdir -p "$OMARCHY_MIGRATION_STATE"

pending=$("$ROOT/bin/omarchy-migrate" --pending 2>/dev/null || true)
! grep -Fxq '1789325478.sh' <<<"$pending" || fail "skipped kernel migration is not pending"

# Only the skipped kernel migration is unrecorded; others may also be pending
# in a source tree. Run migrate against a copy that contains just that file.
mkdir -p "$scratch/omarchy/migrations" "$scratch/bin"
cp "$ROOT/migrations/1789325478.sh" "$ROOT/migrations/artix-skip.txt" "$scratch/omarchy/migrations/"
cat > "$scratch/bin/omarchy-pkg-add" <<'SH'
#!/bin/bash
echo "unexpected omarchy-pkg-add $*" >&2
exit 1
SH
chmod +x "$scratch/bin/omarchy-pkg-add"
export PATH="$scratch/bin:$PATH"
export OMARCHY_PATH="$scratch/omarchy"
export OMARCHY_MIGRATION_STATE="$scratch/state2"
mkdir -p "$OMARCHY_MIGRATION_STATE"
"$ROOT/bin/omarchy-migrate" >/dev/null
[[ -f $OMARCHY_MIGRATION_STATE/1789325478.sh ]] || fail "skipped migrations are recorded complete"
pass "linux-omarchy kernel migration is skipped on Artix"
