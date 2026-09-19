#!/bin/bash
# Full-disk layouts must leave one sector between consecutive parted ranges.

set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
configurator="$root/install-media/root/configurator"
grep -Fqx 'main_partition_start=$((boot_partition_size + boot_partition_start + mib))' "$configurator"
grep -Fqx 'main_partition_size=$((disk_size_in_mib - main_partition_start - gpt_backup_reserve))' "$configurator"

if ! command -v parted >/dev/null 2>&1; then
  echo "SKIP: parted is not installed"
  exit 0
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
image="$work/full-disk.qcow2"
mib=$((1024 * 1024))
gib=$((mib * 1024))
disk_size=$((64 * gib))
disk_size_in_mib=$((disk_size / mib * mib))
gpt_backup_reserve=$mib
boot_partition_start=$mib
boot_partition_size=$((2 * gib))
main_partition_start=$((boot_partition_start + boot_partition_size + mib))
main_partition_size=$((disk_size_in_mib - main_partition_start - gpt_backup_reserve))

truncate -s "$disk_size" "$image"
parted --script "$image" mklabel gpt
parted --script "$image" mkpart ESP fat32 "${boot_partition_start}B" "$((boot_partition_start + boot_partition_size))B"
parted --script "$image" mkpart ROOT btrfs "${main_partition_start}B" "$((main_partition_start + main_partition_size))B"

numbers=$(parted -ms "$image" unit s print | awk -F: 'NR > 2 { print $1 }' | tr '\n' ' ')
[[ $numbers == '1 2 ' ]] || {
  echo "FAIL: expected ESP and root partitions, got: $numbers" >&2
  exit 1
}

echo 'PASS: full-disk partition boundaries do not overlap'
