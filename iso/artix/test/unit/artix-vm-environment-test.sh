#!/bin/bash

set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
CHECK="$ROOT/builder/check-vm-environment.sh"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/bin" "$tmpdir/firmware"
for command_name in qemu-system-x86_64 qemu-img socat magick tesseract; do
  ln -s /usr/bin/true "$tmpdir/bin/$command_name"
done
touch "$tmpdir/firmware/OVMF_CODE.fd"

# The test host may not expose KVM; replace the explicit check with a readable
# temporary file while retaining the production script's requirement verbatim.
sed -e 's|/dev/kvm|"$OMARCHY_ARTIX_KVM_DEVICE"|g' -e 's/qemu-img/qemu-img-required/g' \
  "$CHECK" >"$tmpdir/check"
chmod +x "$tmpdir/check"
ln -s /usr/bin/true "$tmpdir/bin/qemu-img-required"
touch "$tmpdir/kvm"
PATH="$tmpdir/bin:$PATH" OMARCHY_ARTIX_KVM_DEVICE="$tmpdir/kvm" \
  OMARCHY_ARTIX_OVMF_CODE="$tmpdir/firmware/OVMF_CODE.fd" "$tmpdir/check" \
  | grep -Fx 'Artix VM acceptance environment is ready.'

rm "$tmpdir/bin/qemu-img-required"
if PATH="$tmpdir/bin:$PATH" OMARCHY_ARTIX_KVM_DEVICE="$tmpdir/kvm" \
  OMARCHY_ARTIX_OVMF_CODE="$tmpdir/firmware/OVMF_CODE.fd" "$tmpdir/check" >"$tmpdir/output" 2>&1; then
  echo 'expected missing qemu-img to fail' >&2
  exit 1
fi
grep -F 'required VM command is unavailable: qemu-img-required' "$tmpdir/output"
