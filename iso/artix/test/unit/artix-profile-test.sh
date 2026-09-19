#!/bin/bash

set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
PROFILE="$ROOT/builder/profile/omarchy-artix/profile.yaml"
PREPARE="$ROOT/builder/prepare-profile.sh"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

grep -Fx 'source_profiles=${ARTIX_ISO_PROFILES_DIR:-/usr/share/artools/iso-profiles}' "$PREPARE"
grep -Fx '      - networkmanager-dinit' "$PROFILE"
grep -Fx '      - artix-live-dinit' "$PROFILE"
grep -Fx '  user-services: []' "$PROFILE"
grep -Fqx '  autologin: false' "$PROFILE"
grep -Fx '    - artix-archlinux-support' "$PROFILE"
grep -Fx '    - artools-base' "$PROFILE"
grep -Fx '    - btrfs-progs' "$PROFILE"
grep -Fx '    - dosfstools' "$PROFILE"
grep -Fx '    - efibootmgr' "$PROFILE"
grep -Fx '    dinit: []' "$PROFILE"
if grep -Fqx '      - sddm-dinit' "$PROFILE"; then
  echo 'live profile must start the Omarchy installer, not SDDM' >&2
  exit 1
fi
if rg -n 'systemd|openrc|runit|s6' "$PROFILE" | rg -v 'openrc: \[\]|runit: \[\]|s6: \[\]' | grep -q .; then
  echo 'profile has a non-dinit init dependency' >&2
  exit 1
fi

mkdir -p "$tmpdir/source/common" "$tmpdir/runtime/install/provisioning" "$tmpdir/bin"
touch "$tmpdir/source/common/artix-owned"
printf '%s\n' 'packages-base:' '  - crda' '  - vi' > "$tmpdir/source/common/common.yaml"
touch "$tmpdir/runtime/logo.txt" "$tmpdir/runtime/install/provisioning/setup-form.sh"
printf '%s\n' '#!/bin/bash' \
  'for arg in "$@"; do [[ $arg == *SHASUMS256.txt ]] && { printf "%s  %s\\n" "545ea538461003efdc8c81c244531b003f6f26cfccf6c0073b3239fdedf49446" "node-vtest-linux-x64.tar.gz"; exit; }; done' \
  'for ((i = 1; i <= $#; i++)); do [[ ${!i} == -o ]] && { next=$((i + 1)); printf node > "${!next}"; exit; }; done' \
  'printf node' \
  > "$tmpdir/bin/curl"
chmod +x "$tmpdir/bin/curl"
node_sha=$(printf node | sha256sum | awk '{print $1}')
PATH="$tmpdir/bin:$PATH" ARTIX_ISO_PROFILES_DIR="$tmpdir/source" OMARCHY_ARTIX_NODE_VERSION=vtest OMARCHY_ARTIX_NODE_SHA256="$node_sha" "$PREPARE" "$tmpdir/workspace" "$tmpdir/runtime" \
  | grep -F "Prepared Artix dinit profile at $tmpdir/workspace/iso-profiles/omarchy-artix"
test -f "$tmpdir/workspace/iso-profiles/common/artix-owned"
grep -Fx '  - wireless-regdb' "$tmpdir/workspace/iso-profiles/common/common.yaml"
grep -Fx '  - vim' "$tmpdir/workspace/iso-profiles/common/common.yaml"
! grep -Fq '/dist/latest' "$PREPARE"
cmp "$PROFILE" "$tmpdir/workspace/iso-profiles/omarchy-artix/profile.yaml"
test -x "$tmpdir/workspace/iso-profiles/omarchy-artix/root-overlay/root/configurator"
test -f "$tmpdir/workspace/iso-profiles/omarchy-artix/root-overlay/usr/share/omarchy-iso/setup-form.sh"
test -f "$tmpdir/workspace/iso-profiles/omarchy-artix/root-overlay/opt/packages/node-vtest-linux-x64.tar.gz"
test -x "$tmpdir/workspace/iso-profiles/omarchy-artix/root-overlay/usr/share/omarchy-iso/artix-install.sh"
test ! -e "$tmpdir/workspace/iso-profiles/omarchy-artix/root-overlay/usr/share/omarchy-iso/artix-services/tlp-pd"
test ! -e "$tmpdir/workspace/iso-profiles/omarchy-artix/root-overlay/usr/share/omarchy-iso/orchestrator"
test -x "$tmpdir/workspace/iso-profiles/omarchy-artix/root-overlay/root/.automated_script.sh"
test -f "$tmpdir/workspace/iso-profiles/omarchy-artix/root-overlay/usr/lib/dinit.d/dinit-user-spawn"
grep -Fx 'type = internal' "$tmpdir/workspace/iso-profiles/omarchy-artix/root-overlay/usr/lib/dinit.d/dinit-user-spawn"
for service in early-fs-fstab.target pacman-init udevd-early udevd udev-trigger udev-settle; do
  test ! -e "$tmpdir/workspace/iso-profiles/omarchy-artix/root-overlay/etc/dinit.d/$service"
done
root_ro="$tmpdir/workspace/iso-profiles/omarchy-artix/root-overlay/etc/dinit.d/root-ro"
test -f "$root_ro"
grep -Fx 'type = internal' "$root_ro"
root_rw="$tmpdir/workspace/iso-profiles/omarchy-artix/root-overlay/etc/dinit.d/early-root-rw.target"
test -f "$root_rw"
grep -Fx 'type = internal' "$root_rw"
agetty="$tmpdir/workspace/iso-profiles/omarchy-artix/root-overlay/etc/dinit.d/agetty"
test -f "$agetty"
grep -Fx 'type = internal' "$agetty"
test -f "$tmpdir/workspace/iso-profiles/omarchy-artix/root-overlay/etc/dinit.d/getty@tty1"
grep -Fx 'type = internal' "$tmpdir/workspace/iso-profiles/omarchy-artix/root-overlay/etc/dinit.d/getty@tty1"
launcher="$tmpdir/workspace/iso-profiles/omarchy-artix/root-overlay/etc/dinit.d/omarchy-install"
grep -Fx 'command = /usr/bin/openvt -c 1 -f -w -- /root/.automated_script.sh' "$launcher"
grep -Fx '@include ../omarchy-install' \
  "$tmpdir/workspace/iso-profiles/omarchy-artix/root-overlay/etc/dinit.d/boot.d/omarchy-install"
if command -v dinit-check >/dev/null 2>&1; then
  dinit-check \
    -d "$tmpdir/workspace/iso-profiles/omarchy-artix/root-overlay/etc/dinit.d" \
    -d /usr/lib/dinit.d \
    omarchy-install
fi
grub_kernel_cfg="$tmpdir/workspace/iso-profiles/omarchy-artix/live-overlay/usr/share/grub/cfg/kernels.cfg"
grub_cfg="$tmpdir/workspace/iso-profiles/omarchy-artix/live-overlay/usr/share/grub/cfg/grub.cfg"
test -f "$grub_cfg"
grep -Fx 'set kopts="lang=en_US keytable=us tz=UTC console=ttyS0,115200"' "$grub_cfg"
grep -Fx 'insmod serial' "$grub_cfg"
grep -Fx '    terminal_output --append serial' "$grub_cfg"
grep -Fx 'set default=0' "$grub_cfg"
grep -Fx 'source /boot/grub/kernels.cfg' "$grub_cfg"
if rg -n 'boot_menu|show_timezones|show_keymaps|show_languages|artix' "$grub_cfg"; then
  echo 'live GRUB configuration leaks Artix setup menus' >&2
  exit 1
fi
test -f "$grub_kernel_cfg"
grep -F 'menuentry "Omarchy Installer" --class=omarchy' "$grub_kernel_cfg"
test "$(rg -c '^    menuentry ' "$grub_kernel_cfg")" = 1
grep -Fx '        linux /boot/vmlinuz-$2' "$grub_kernel_cfg"
grep -Fx '        initrd /boot/intel-ucode.img /boot/amd-ucode.img /boot/initramfs-x86_64.img' "$grub_kernel_cfg"
grep -Fx 'set default=0' "$grub_kernel_cfg"
grep -Fx 'set timeout_style=hidden' "$grub_kernel_cfg"
grep -Fx 'set timeout=0' "$grub_kernel_cfg"
for command in omarchy-cidata-load omarchy-install-dashboard omarchy-install-diagnose-media omarchy-iso-cleanup-disk omarchy-iso-install; do
  test -x "$tmpdir/workspace/iso-profiles/omarchy-artix/root-overlay/usr/local/bin/$command"
done
test "$(< "$tmpdir/workspace/iso-profiles/omarchy-artix/root-overlay/root/omarchy_mirror")" = stable
grep -Fx 'OMARTIX_CORE_PACKAGE=omartix' "$tmpdir/workspace/iso-profiles/omarchy-artix/root-overlay/usr/share/omarchy-iso/package-targets"
grep -Fx 'OMARCHY_NVIM_PACKAGE=nvim' "$tmpdir/workspace/iso-profiles/omarchy-artix/root-overlay/usr/share/omarchy-iso/package-targets"

if ARTIX_ISO_PROFILES_DIR="$tmpdir/source" "$PREPARE" "$tmpdir/workspace" "$tmpdir/runtime" >"$tmpdir/output" 2>&1; then
  echo 'expected existing profile to be protected' >&2
  exit 1
fi
grep -F 'refusing to overwrite existing profile' "$tmpdir/output"

PATH="$tmpdir/bin:$PATH" ARTIX_ISO_PROFILES_DIR="$tmpdir/source" OMARCHY_ARTIX_NODE_VERSION=vtest OMARCHY_ARTIX_NODE_SHA256="$node_sha" ARTIX_REPLACE_PROFILE=1 "$PREPARE" "$tmpdir/workspace" "$tmpdir/runtime" \
  | grep -F "Prepared Artix dinit profile at $tmpdir/workspace/iso-profiles/omarchy-artix"
grep -Fx '  - wireless-regdb' "$tmpdir/workspace/iso-profiles/common/common.yaml"
