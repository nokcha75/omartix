#!/bin/bash

set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
backend="$ROOT/install-media/usr/share/omarchy-iso/artix-install.sh"
entrypoint="$ROOT/install-media/usr/local/bin/omarchy-iso-install"

bash -n "$backend" "$entrypoint"
shellcheck -S warning "$backend" "$entrypoint"

grep -Fqx 'exec /usr/share/omarchy-iso/artix-install.sh "$@"' "$entrypoint"
grep -Fq 'basestrap -C "$pacman_config" "$target" "${base_packages[@]}"' "$backend"
grep -Fq 'cryptsetup blkid openssl runuser' "$backend"
grep -Fq 'git lua51 luarocks zsh artix-archlinux-support' "$backend"
grep -Fq "info 'initializing the Pacman signing keyring'" "$backend"
grep -Fq 'pacman-key --init' "$backend"
grep -Fq 'pacman-key --populate artix' "$backend"
grep -Fq 'pacman-key --lsign-key "$(<"$repository/omarchy-artix.fingerprint")"' "$backend"
if grep -Fq 'cp "$pacman_config" "$target/etc/pacman.conf"' "$backend"; then
  echo 'bootstrap-only pacman.conf must not replace the target configuration' >&2
  exit 1
fi
# Artix uses a lower-case package name but its dinit service is named with an
# upper-case M. Keep the two identifiers distinct: using the service name in
# base_packages makes pacman abort before the target has been bootstrapped.
grep -Fq 'dbus-dinit networkmanager networkmanager-dinit openresolv' "$backend"
grep -Fq 'for service in NetworkManager sddm ufw userspawn avahi-daemon bluetoothd cupsd dockerd tlp limine-snapper-sync zramen cronie earlyoom; do enable_dinit "$service"; done' "$backend"
grep -Fq 'ACTIVE_CONSOLES="/dev/tty[2-6]"' "$backend"
grep -Fq 'rm -f "$target/etc/dinit.d/boot.d/getty@tty1"' "$backend"
grep -Fq "if grep -qx 'GenuineIntel' /proc/cpuinfo; then enable_dinit thermald; fi" "$backend"
! grep -Fq 'dbus-dinit NetworkManager networkmanager-dinit openresolv' "$backend"
grep -Fq 'artix-archlinux-support "$OMARCHY_NVIM_PACKAGE" "$OMARTIX_CORE_PACKAGE"' "$backend"
grep -Fq 'ensure_arch_extra_repository' "$backend"
grep -Fq 'pacman-key --populate archlinux' "$backend"
grep -Fq 'artix-chroot "$target" pacman --noconfirm -Syu --needed "${runtime_packages[@]}"' "$backend"
grep -Fq 'Include = /etc/pacman.d/omartix-arch-extra.conf' "$backend"
grep -Fq 'Include = /etc/pacman.d/omartix-offline.conf' "$backend"
grep -Fq 'offline_source=/usr/share/omarchy-iso/artix-repo' "$backend"
grep -Fq 'destination="$target/var/cache/omarchy/mirror/offline"' "$backend"
grep -Fq 'remove_offline_provider' "$backend"
grep -Fq '/usr/bin/omarchy-apply-system --defer-provisioning --first-install' "$backend"
grep -Fq '/usr/bin/omarchy-apply-system --install-user "$username" --first-install' "$backend"
if grep -Fq 'omarchy-apply-system-artix' "$backend"; then
  echo 'installer must call the dinit implementation through Omarchy\x27s standard command name' >&2
  exit 1
fi
if grep -Fq 'cp /etc/pacman.conf "$target/etc/pacman.conf"' "$backend"; then
  echo 'live offline pacman.conf must not replace the installed target configuration' >&2
  exit 1
fi
grep -Fq 'cryptsetup luksFormat --type luks2 --batch-mode --key-file - "$root_partition"' "$backend"
grep -Fq 'translate_package_list runtime_packages' "$backend"
grep -Fq 'target_repository="$target/usr/share/omarchy-iso/artix-repo"' "$backend"
grep -Fq 'Include = /etc/pacman.d/omartix-installer.conf' "$backend"
grep -Fq 'artix-chroot "$target" pacman-key --add /usr/share/omarchy-iso/artix-repo/omarchy-artix.gpg' "$backend"
grep -Fq 'SigLevel = Optional DatabaseRequired' "$backend"
grep -Fq 'rm -rf "$target_repository"' "$backend"
! grep -Fq 'uwsm) ;;' "$backend"
! grep -Fq 'usage) ;;' "$backend"
! grep -Fq 'artix-services/tlp-pd' "$backend"
grep -Fq 'kernel-modules-hook) ;;' "$backend"
grep -Fq 'nvim) printf '\''%s\n'\'' neovim ;;' "$backend"
grep -Fq 'vi) printf '\''%s\n'\'' vim ;;' "$backend"
grep -Fq 'bluez-tools) printf '\''%s\n'\'' bluez-deprecated-tools ;;' "$backend"
grep -Fq 'chromium) printf '\''%s\n'\'' omarchy-chromium-bin ;;' "$backend"
grep -Fq 'full-disk install requires Omarchy Btrfs subvolumes' "$backend"
grep -Fq "die 'bundled Artix package repository is incomplete'" "$backend"
grep -Fq 'if [[ $encrypted == true ]]; then' "$backend"
grep -Fq "kernel_package=\$(jq -r '.omarchy_install.storage.kernel // .kernels[0] // \"linux\"' \"\$config\")" "$backend"
grep -Fq 'cryptkey=rootfs:/etc/omarchy/provisioning.key' "$backend"
grep -Fq 'FILES+=(/etc/omarchy/provisioning.key)' "$backend"
grep -Fq '99-omarchy-provisioning-encrypt.conf' "$backend"
grep -Fq 'if [[ $encrypted == true ]]; then' "$backend"
grep -Fq 'if [[ " ${HOOKS[*]} " != *" encrypt "* ]]; then' "$backend"
grep -Fq 'if [[ $_omartix_hook == block ]]; then' "$backend"
grep -Fq '_omartix_encrypt_hooks+=(encrypt)' "$backend"
grep -Fq 'artix-chroot "$target" limine-update' "$backend"
grep -Fq 'artix-chroot "$target" runuser -u "$user" -- env --unset=XDG_RUNTIME_DIR' "$backend"
! grep -Fq 'artix-chroot -u "$user"' "$backend"
grep -Fq 'printf '\''%s:%s\n'\'' "$username" "$password_hash" | artix-chroot "$target" chpasswd --encrypted' "$backend"
grep -Fq 'installed_password_hash=$(artix-chroot "$target" getent shadow "$username" | cut -d: -f2)' "$backend"
grep -Fq '[[ $installed_password_hash == "$password_hash" ]] || die "failed to set password hash for $username"' "$backend"
grep -Fq "[[ -x \$target/bin/zsh ]] || die 'zsh is missing from the target; cannot create the Omarchy login user'" "$backend"
grep -Fq "(( \${#authorized_keys[@]} > 0 )) || die 'authorized-keys file contains no public keys'" "$backend"
grep -Fq 'require_command ssh-keygen' "$backend"
grep -Fq "ssh-keygen -lf /dev/stdin <<<\"\$authorized_key\" >/dev/null 2>&1 || die 'authorized-keys file contains an invalid public key'" "$backend"
grep -Fq "[[ -s \$target/home/\$username/.ssh/authorized_keys ]] || die 'authorized keys were not written to the target'" "$backend"
grep -Fq "grep -qxF \"\$authorized_key\" \"\$target/home/\$username/.ssh/authorized_keys\" || die 'authorized key verification failed'" "$backend"
grep -Fq "grep -qxF 'depends-on      = local.target' \"\$target/etc/dinit.d/sshd\"" "$backend"
grep -Fq "printf '\\ndepends-on      = local.target\\n' >>\"\$target/etc/dinit.d/sshd\"" "$backend"
grep -Fq 'artix-chroot "$target" limine bios-install "$boot_disk"' "$backend"
grep -Fq 'ENABLE_UKI=no' "$backend"
grep -Fq 'enable_dinit omarchy-provision-owner' "$backend"
grep -Fq 'enable_dinit omarchy-tailscale-join' "$backend"
! grep -Eqi '(^|[^[:alnum:]_])(python|archinstall|systemctl|arch-chroot)([^[:alnum:]_]|$)' "$backend"
