#!/bin/bash
# Build the Artix+dinit ISO from this Omartix checkout.

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/../.." && pwd)
workspace=${1:-"$script_dir/artools-workspace"}
output_dir=${2:-"$script_dir/iso-output"}

exec "$script_dir/builder/build-iso.sh" "$workspace" "$output_dir" "$repo_root"
