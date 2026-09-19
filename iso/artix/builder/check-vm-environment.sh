#!/bin/bash
# Verify that an Artix build host can run the QEMU acceptance matrix.

set -euo pipefail

failures=0

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  failures=1
}

for command_name in qemu-system-x86_64 qemu-img socat magick tesseract; do
  command -v "$command_name" >/dev/null 2>&1 || fail "required VM command is unavailable: $command_name"
done

[[ -r /dev/kvm && -w /dev/kvm ]] || fail 'KVM is unavailable; expose /dev/kvm to run the acceptance VM'

ovmf_code=${OMARCHY_ARTIX_OVMF_CODE:-}
if [[ -z $ovmf_code ]]; then
  for candidate in /usr/share/edk2-ovmf/x64/OVMF_CODE.fd /usr/share/edk2/x64/OVMF_CODE.4m.fd; do
    if [[ -r $candidate ]]; then
      ovmf_code=$candidate
      break
    fi
  done
fi
[[ -n $ovmf_code && -r $ovmf_code ]] || fail 'UEFI OVMF code image is unavailable; set OMARCHY_ARTIX_OVMF_CODE'

if (( failures )); then
  cat >&2 <<'EOF'

Install the QEMU, OVMF, socat, ImageMagick, and Tesseract packages on the
Artix build host, and make /dev/kvm available to the build user. Run this
check before building an Artix ISO for VM acceptance.
EOF
  exit 1
fi

printf 'Artix VM acceptance environment is ready.\n'
