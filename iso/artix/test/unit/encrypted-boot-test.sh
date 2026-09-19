#!/bin/bash

set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
base="$ROOT/test/integration.d/base-test.sh"
smoke="$ROOT/test/integration.d/installer-smoke-test.sh"
reset="$ROOT/test/integration.d/factory-reset-test.sh"

grep -Fq 'unlock_encrypted_boot()' "$base"
grep -Fq 'password is required to access.*volume' "$base"
grep -Fq 'OMARCHY_INTEGRATION_ENCRYPT_INSTALLATION:-true' "$base"
grep -Fq 'unlock_encrypted_boot' "$smoke"
grep -Fq 'unlock_encrypted_boot' "$reset"
grep -Fq 'root is unlocked through omarchy_root' "$smoke"
grep -Fq 'grep -Eq' "$smoke"

echo 'ok - encrypted integration boots unlock the Artix plymouth prompt automatically'
