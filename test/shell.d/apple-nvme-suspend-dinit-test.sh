#!/bin/bash

set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "$0")/base-test.sh"

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

stub_bin="$test_tmp/bin"
service_dir="$test_tmp/dinit.d"
boot_dir="$service_dir/boot.d"
product_name="$test_tmp/product_name"
nvme_device="$test_tmp/d3cold_allowed"
mkdir -p "$stub_bin"
touch "$nvme_device"
printf 'MacBookPro13,2\n' >"$product_name"

cat >"$stub_bin/sudo" <<'SH'
#!/bin/bash
exec "$@"
SH
chmod +x "$stub_bin/sudo"

script="$test_tmp/fix-suspend-nvme.sh"
sed -e "s|/sys/class/dmi/id/product_name|$product_name|" \
    -e "s|/sys/bus/pci/devices/0000:01:00.0/d3cold_allowed|$nvme_device|" \
    "$ROOT/install/hardware/apple/fix-suspend-nvme.sh" >"$script"

PATH="$stub_bin:$PATH" \
  OMARTIX_DINIT_SERVICE_DIR="$service_dir" \
  OMARTIX_DINIT_BOOT_DIR="$boot_dir" \
  bash -euo pipefail "$script" >/dev/null

grep -Fx 'type = process' "$service_dir/omarchy-nvme-suspend-fix" >/dev/null ||
  fail "NVMe fix is a dinit process service"
grep -F 'd3cold_allowed' "$service_dir/omarchy-nvme-suspend-fix" >/dev/null ||
  fail "NVMe dinit service preserves the d3cold workaround"
[[ -L $boot_dir/omarchy-nvme-suspend-fix && $(readlink "$boot_dir/omarchy-nvme-suspend-fix") == ../omarchy-nvme-suspend-fix ]] ||
  fail "NVMe dinit service is enabled at boot"
! rg -q '\bsystemctl\b|/etc/systemd/' "$ROOT/install/hardware/apple/fix-suspend-nvme.sh" ||
  fail "NVMe fix has no systemd path"

pass "Apple NVMe suspend workaround uses a dinit one-shot service"
