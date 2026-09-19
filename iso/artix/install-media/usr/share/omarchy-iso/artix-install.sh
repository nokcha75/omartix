#!/usr/bin/env bash
# Omarchy's Artix+dinit installer backend.
#
# The configurator owns the UI and produces its established JSON files. This
# backend deliberately uses Bash plus native Artix tools only. The target is
# installed without a compatibility backend or a separate language runtime.

set -Eeuo pipefail

target=/mnt
config=
creds=
full_name_file=
email_file=
authorized_keys_file=
tailscale_authkey_file=
created_target_mounts=false
declare -a setup_mounts=()

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
info() { printf '› %s\n' "$*"; }
require_command() { command -v "$1" >/dev/null 2>&1 || die "live ISO is missing: $1"; }

cleanup() {
  local path
  for path in "${setup_mounts[@]:-}"; do umount "$path" >/dev/null 2>&1 || true; done
  [[ $created_target_mounts == true ]] || return 0
  for path in "${target_esp:-$target/boot}" "$target/var/cache/pacman/pkg" "$target/var/log" "$target/home" "$target"; do
    umount "$path" >/dev/null 2>&1 || true
  done
}
trap cleanup EXIT

while (($#)); do
  case $1 in
    --config) config=$2; shift 2 ;;
    --creds) creds=$2; shift 2 ;;
    --full-name-file) full_name_file=$2; shift 2 ;;
    --email-file) email_file=$2; shift 2 ;;
    --encrypt-file|--defer-provisioning-file) shift 2 ;;
    --authorized-keys-file) authorized_keys_file=$2; shift 2 ;;
    --tailscale-authkey-file) tailscale_authkey_file=$2; shift 2 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[[ -r $config ]] || die "configuration is not readable: ${config:-<unset>}"
[[ -r $creds ]] || die "credentials are not readable: ${creds:-<unset>}"
for command in jq basestrap fstabgen artix-chroot parted partprobe udevadm wipefs mkfs.fat mkfs.btrfs btrfs mount umount cryptsetup blkid openssl runuser; do
  require_command "$command"
done
[[ -d /sys/firmware/efi ]] && require_command efibootmgr

mode=$(jq -er '.omarchy_install.mode' "$config") || die 'configuration has no omarchy_install.mode'
[[ $mode == full_disk || $mode == protected ]] || die "unsupported Omarchy install mode: $mode"
if [[ ! -d /sys/firmware/efi && $mode != full_disk ]]; then
  die 'installing alongside existing data requires UEFI firmware'
fi
defer_provisioning=$(jq -r '.omarchy_install.defer_provisioning // false' "$config")
[[ $defer_provisioning == true || $defer_provisioning == false ]] || die 'invalid defer_provisioning flag'
boot_mount=$(jq -r '.omarchy_install.boot.esp_mount // "/boot"' "$config")
[[ $boot_mount == /* && $boot_mount != *'..'* ]] || die 'invalid ESP mountpoint'
target_esp="$target$boot_mount"
repository=/usr/share/omarchy-iso/artix-repo
pacman_config=$repository/pacman.conf
[[ -s $pacman_config && -s $repository/omarchy-artix.gpg && -s $repository/omarchy-artix.fingerprint ]] || die 'bundled Artix package repository is incomplete'

OMARTIX_CORE_PACKAGE=omartix
OMARCHY_NVIM_PACKAGE=nvim
if [[ -r /usr/share/omarchy-iso/package-targets ]]; then
  # Build-owned static assignments, not user input.
  # shellcheck disable=SC1091
  source /usr/share/omarchy-iso/package-targets
fi

part_path() {
  [[ $1 == *[0-9] ]] && printf '%sp%s\n' "$1" "$2" || printf '%s%s\n' "$1" "$2"
}

map_package() {
  case $1 in
    # The single Omartix core package is installed during bootstrap.  Do not
    # ask pacman to replace it with an upstream Omarchy split package while
    # processing the shipped package manifests.
    omarchy|omarchy-dev|omarchy-settings|omarchy-settings-dev) ;;
    omarchy-keyring) ;;
    # This Arch-only pacman hook preserves the currently running kernel's
    # module tree and also ships a systemd cleanup unit. Artix owns kernel
    # lifecycle through its native packages; do not install a foreign hook.
    kernel-modules-hook) ;;
    # Artix ships Neovim under its upstream package name. `omarchy-nvim` is
    # a separate settings package from the bundled project repository, so it
    # must remain untouched.
    nvim) printf '%s\n' neovim ;;
    # Artix retains the older BlueZ command-line tools under this explicit
    # package name.
    bluez-tools) printf '%s\n' bluez-deprecated-tools ;;
    # These project-maintained packages preserve Omarchy's Chromium and mise
    # integration where Artix has no public package with the required layout.
    chromium) printf '%s\n' omarchy-chromium-bin ;;
    # `vi` is virtual and makes pacman ask an unattended install to choose a
    # provider.  Vim supplies the expected editor without that prompt.
    vi) printf '%s\n' vim ;;
    power-profiles-daemon) printf '%s\n' tlp-pd ;;
    *) printf '%s\n' "$1" ;;
  esac
}

translate_package_list() {
  local -n packages=$1
  local -a translated=()
  local package mapped existing
  for package in "${packages[@]}"; do
    mapped=$(map_package "$package")
    [[ -n $mapped ]] || continue
    for existing in "${translated[@]:-}"; do [[ $existing == "$mapped" ]] && continue 2; done
    translated+=("$mapped")
  done
  packages=("${translated[@]}")
}

ensure_arch_extra_repository() {
  local provider_config=$target/etc/pacman.d/omartix-arch-extra.conf

  # `artix-archlinux-support` supplies Arch's keyring and mirror list, but
  # leaves repository activation to the installed pacman.conf. Preserve an
  # existing [extra] section when Artix already provides one; otherwise add a
  # final include so system/world/galaxy always retain precedence.
  if ! artix-chroot "$target" pacman-conf --repo-list | grep -Fxq extra; then
    cat >"$provider_config" <<'EOF'
# Omartix uses Artix repositories first. Arch extra is a narrow compatibility
# provider for explicitly audited desktop applications, never an init provider.
[extra]
Include = /etc/pacman.d/mirrorlist-arch
EOF
    printf '\nInclude = /etc/pacman.d/omartix-arch-extra.conf\n' >>"$target/etc/pacman.conf"
  fi

  info 'enabling the Arch extra compatibility keyring'
  artix-chroot "$target" pacman-key --populate archlinux
}

enable_dinit() {
  local service=$1 source="$target/etc/dinit.d/$1" destination="$target/etc/dinit.d/boot.d/$1"
  [[ -f $source ]] || die "dinit service definition missing: /etc/dinit.d/$service"
  mkdir -p "${destination%/*}"
  ln -srf "$source" "$destination"
}

config_value() { jq -er "$1" "$config"; }

prepare_full_disk() {
  local disk esp_start esp_size root_start root_size encryption passphrase top
  disk=$(config_value '.disk_config.device_modifications[0].device')
  [[ $disk == /dev/* && -b $disk ]] || die "invalid install disk: $disk"
  [[ $(jq '[.disk_config.device_modifications[]? | select(.wipe == true)] | length' "$config") == 1 ]] || die 'full-disk install requires exactly one wiped disk'
  [[ $(jq '.disk_config.device_modifications[0].partitions | length' "$config") == 2 ]] || die 'full-disk install requires exactly two partitions'
  [[ $(config_value '.disk_config.device_modifications[0].partitions[0].fs_type') == fat32 ]] || die 'Omarchy ESP must be FAT32'
  [[ $(config_value '.disk_config.device_modifications[0].partitions[1].fs_type') == btrfs ]] || die 'Omarchy root must be Btrfs'
  esp_start=$(config_value '.disk_config.device_modifications[0].partitions[0].start.value')
  esp_size=$(config_value '.disk_config.device_modifications[0].partitions[0].size.value')
  root_start=$(config_value '.disk_config.device_modifications[0].partitions[1].start.value')
  root_size=$(config_value '.disk_config.device_modifications[0].partitions[1].size.value')
  for bound in "$esp_start" "$esp_size" "$root_start" "$root_size"; do
    [[ $bound =~ ^[1-9][0-9]*$ ]] || die 'wizard supplied invalid partition byte bounds'
  done
  (( esp_start + esp_size <= root_start && root_start + root_size > root_start )) || die 'wizard supplied overlapping or invalid partitions'
  jq -e '.disk_config.device_modifications[0].partitions[1].btrfs == [{"mountpoint":"/","name":"@"},{"mountpoint":"/home","name":"@home"},{"mountpoint":"/var/log","name":"@log"},{"mountpoint":"/var/cache/pacman/pkg","name":"@pkg"}]' "$config" >/dev/null || die 'full-disk install requires Omarchy Btrfs subvolumes'

  info "cleaning holders on $disk"
  /usr/local/bin/omarchy-iso-cleanup-disk "$disk"
  info "creating Omarchy's Btrfs layout on $disk"
  wipefs --all "$disk"
  parted --script "$disk" mklabel gpt
  parted --script "$disk" mkpart ESP fat32 "${esp_start}B" "$((esp_start + esp_size))B"
  parted --script "$disk" set 1 esp on
  parted --script "$disk" mkpart ROOT btrfs "${root_start}B" "$((root_start + root_size))B"
  partprobe "$disk"
  udevadm settle
  esp_partition=$(part_path "$disk" 1)
  root_partition=$(part_path "$disk" 2)
  [[ -b $esp_partition && -b $root_partition ]] || die 'new disk partitions did not appear'
  mkfs.fat -F32 -n OMARCHY_EFI "$esp_partition"

  encryption=$(jq -r '.disk_config.disk_encryption.encryption_type // "no_encryption"' "$config")
  if [[ $encryption != no_encryption ]]; then
    passphrase=$(jq -r '.disk_config.disk_encryption.encryption_password // empty' "$config")
    [[ -n $passphrase ]] || passphrase=$(jq -r '.encryption_password // empty' "$creds")
    [[ -n $passphrase || $defer_provisioning != true ]] || passphrase=$(openssl rand -base64 48)
    [[ -n $passphrase ]] || die 'encrypted install has no LUKS passphrase'
    printf '%s' "$passphrase" | cryptsetup luksFormat --type luks2 --batch-mode --key-file - "$root_partition"
    printf '%s' "$passphrase" | cryptsetup open --key-file - "$root_partition" omarchy_root
    root_device=/dev/mapper/omarchy_root
    install_passphrase=$passphrase
    encrypted=true
  else
    root_device=$root_partition
    install_passphrase=
    encrypted=false
  fi
  mkfs.btrfs --force "$root_device"
  top="$target/.omarchy-btrfs-top"
  mkdir -p "$target" "$top"
  mount -o subvolid=5 "$root_device" "$top"
  btrfs subvolume create "$top/@"
  btrfs subvolume create "$top/@home"
  btrfs subvolume create "$top/@log"
  btrfs subvolume create "$top/@pkg"
  umount "$top"; rmdir "$top"
  mount -o noatime,compress=zstd,subvol=@ "$root_device" "$target"
  mkdir -p "$target/home" "$target/var/log" "$target/var/cache/pacman/pkg" "$target_esp"
  mount -o noatime,compress=zstd,subvol=@home "$root_device" "$target/home"
  mount -o noatime,compress=zstd,subvol=@log "$root_device" "$target/var/log"
  mount -o noatime,compress=zstd,subvol=@pkg "$root_device" "$target/var/cache/pacman/pkg"
  mount "$esp_partition" "$target_esp"
  created_target_mounts=true
}

prepare_protected() {
  root_partition=$(config_value '.omarchy_install.storage.root_device')
  esp_partition=$(config_value '.omarchy_install.storage.esp_device')
  root_device=$(jq -r '.omarchy_install.storage.root_mapper // .omarchy_install.storage.root_device' "$config")
  [[ -b $root_partition && -b $esp_partition && -b $root_device ]] || die 'protected install references unavailable storage'
  mountpoint -q "$target" || die "protected target is not mounted: $target"
  mkdir -p "$target_esp"
  mountpoint -q "$target_esp" || mount "$esp_partition" "$target_esp"
  install_passphrase=$(jq -r '.disk_config.disk_encryption.encryption_password // empty' "$config")
  [[ -n $install_passphrase ]] || install_passphrase=$(jq -r '.encryption_password // empty' "$creds")
  [[ $(jq -r '.omarchy_install.storage.luks_uuid // empty' "$config") != '' ]] && encrypted=true || encrypted=false
}

if [[ $mode == full_disk ]]; then prepare_full_disk; else prepare_protected; fi

# The live ISO's pacman-init service normally prepares this keyring, but the
# installer can reach this point before that service has generated its local
# signing key.  `--lsign-key` below needs that secret key; make the bootstrap
# self-contained rather than relying on service ordering.
info 'initializing the Pacman signing keyring'
pacman-key --init
pacman-key --populate artix
pacman-key --add "$repository/omarchy-artix.gpg"
pacman-key --lsign-key "$(<"$repository/omarchy-artix.fingerprint")"

# Artix names the package `networkmanager`; its dinit service is still named
# `NetworkManager` (enabled below). Keep package and service identifiers apart.
base_packages=(base base-devel dinit elogind elogind-dinit dbus dbus-dinit networkmanager networkmanager-dinit openresolv sddm sddm-dinit openssh openssh-dinit ufw ufw-dinit userspawn userspawn-dinit linux linux-firmware mkinitcpio cryptsetup btrfs-progs limine omarchy-artix-limine-mkinitcpio-hook efibootmgr dbus-dinit-user pipewire pipewire-dinit pipewire-pulse pipewire-pulse-dinit wireplumber wireplumber-dinit avahi-dinit bluez-dinit cups-dinit docker-dinit tlp tlp-dinit tlp-pd tlp-rdw snapper limine-snapper-sync-dinit zramen zramen-dinit cronie cronie-dinit earlyoom earlyoom-dinit thermald thermald-dinit git lua51 luarocks zsh artix-archlinux-support "$OMARCHY_NVIM_PACKAGE" "$OMARTIX_CORE_PACKAGE")
kernel_package=$(jq -r '.omarchy_install.storage.kernel // .kernels[0] // "linux"' "$config")
[[ $kernel_package =~ ^linux([a-z0-9._-]*)?$ ]] || die "invalid kernel package selected by wizard: $kernel_package"
for i in "${!base_packages[@]}"; do [[ ${base_packages[i]} == linux ]] && base_packages[i]=$kernel_package; done
if [[ -n $tailscale_authkey_file && -r $tailscale_authkey_file ]]; then base_packages+=(tailscale tailscale-dinit); fi
translate_package_list base_packages
info 'bootstrapping Artix + dinit'
basestrap -C "$pacman_config" "$target" "${base_packages[@]}"
# $pacman_config is a live-ISO bootstrap wrapper: it includes the live
# /etc/pacman.conf and adds the bundled omarchy-artix repository. Copying it
# into the target would make its Include = /etc/pacman.conf point back to
# itself, so every later chrooted pacman invocation fails after ten recursive
# includes. Keep the normal Artix pacman.conf installed by base instead.

# The runtime manifest includes project packages (yay, Yaru, and
# xdg-terminal-exec) which Artix's public repositories do not carry.  Make
# the signed repository available to the target just for this installation;
# its bootstrap-only configuration must not replace the target pacman.conf.
target_repository="$target/usr/share/omarchy-iso/artix-repo"
target_repository_config="$target/etc/pacman.d/omartix-installer.conf"
mkdir -p "$target_repository" "${target_repository_config%/*}"
cp -a "$repository/." "$target_repository/"
cat >"$target_repository_config" <<'EOF'
[omarchy-artix]
# Omartix signs the database staged into the ISO. Published Omarchy application
# packages are checksum-pinned by that database and are intentionally not
# re-signed with the Omartix key.
SigLevel = Optional DatabaseRequired
Server = file:///usr/share/omarchy-iso/artix-repo
EOF
printf '\nInclude = /etc/pacman.d/omartix-installer.conf\n' >>"$target/etc/pacman.conf"
artix-chroot "$target" pacman-key --init
artix-chroot "$target" pacman-key --populate artix
artix-chroot "$target" pacman-key --add /usr/share/omarchy-iso/artix-repo/omarchy-artix.gpg
artix-chroot "$target" pacman-key --lsign-key "$(<"$repository/omarchy-artix.fingerprint")"
ensure_arch_extra_repository
fstabgen -U "$target" >"$target/etc/fstab"

for service in NetworkManager sddm ufw userspawn avahi-daemon bluetoothd cupsd dockerd tlp limine-snapper-sync zramen cronie earlyoom; do enable_dinit "$service"; done
# SDDM owns VT1. Artix dinit-rc otherwise starts getty@tty1 from ACTIVE_CONSOLES
# and sddm-helper then fails with HELPER_TTY_ERROR.
install -d -m 0755 "$target/etc/dinit.d/config"
cat >"$target/etc/dinit.d/config/console.conf" <<'EOF'
#!/bin/sh

# tty1 is reserved for SDDM. Recovery consoles remain on tty2-tty6.
ACTIVE_CONSOLES="/dev/tty[2-6]"
EOF
rm -f "$target/etc/dinit.d/boot.d/getty@tty1"
# thermald only manages Intel thermal hardware. Starting it on an AMD machine
# or a VM without Intel thermal zones produces a permanent failed dinit
# service, so enable it only where it can provide a benefit.
if grep -qx 'GenuineIntel' /proc/cpuinfo; then enable_dinit thermald; fi

hostname=$(config_value '.hostname')
keymap=$(config_value '.locale_config.kb_layout')
timezone=$(config_value '.timezone')
[[ $hostname != *[[:space:]]* && $keymap =~ ^[A-Za-z0-9_.-]+$ && $timezone != /* && $timezone != *..* ]] || die 'wizard supplied invalid identity data'
printf '%s\n' "$hostname" >"$target/etc/hostname"
printf 'KEYMAP=%s\nXKBLAYOUT=%s\n' "$keymap" "$keymap" >"$target/etc/vconsole.conf"
artix-chroot "$target" ln -sf "/usr/share/zoneinfo/$timezone" /etc/localtime

username=$(jq -r '.users[0].username // empty' "$creds")
password_hash=$(jq -r '.users[0].enc_password // empty' "$creds")
if [[ $defer_provisioning == false ]]; then
  [[ $username =~ ^[a-z_][a-z0-9_-]*$ && -n $password_hash && $password_hash != *$'\n'* ]] || die 'wizard supplied invalid user credentials'
  [[ -x $target/bin/zsh ]] || die 'zsh is missing from the target; cannot create the Omarchy login user'
  artix-chroot "$target" useradd -m -G wheel -s /bin/zsh "$username"
  printf '%s:%s\n' "$username" "$password_hash" | artix-chroot "$target" chpasswd --encrypted
  installed_password_hash=$(artix-chroot "$target" getent shadow "$username" | cut -d: -f2)
  [[ $installed_password_hash == "$password_hash" ]] || die "failed to set password hash for $username"
  printf '%%wheel ALL=(ALL:ALL) ALL\n' >"$target/etc/sudoers.d/10-wheel"
  chmod 440 "$target/etc/sudoers.d/10-wheel"
  for service in pipewire pipewire-pulse wireplumber; do
    [[ -f $target/etc/dinit.d/user/$service ]] || die "dinit user service definition missing: $service"
    mkdir -p "$target/home/$username/.config/dinit.d/boot.d"
    ln -srf "$target/etc/dinit.d/user/$service" "$target/home/$username/.config/dinit.d/boot.d/$service"
  done
  artix-chroot "$target" chown -R "$username:$username" "/home/$username/.config/dinit.d"
fi

manifest=$target/usr/share/omarchy/install/omarchy-base.packages
[[ -r $manifest ]] || die 'Omarchy runtime package did not provide omarchy-base.packages'
mapfile -t runtime_packages < <(sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "$manifest")
translate_package_list runtime_packages
info 'installing Omarchy runtime packages'
artix-chroot "$target" pacman --noconfirm -Syu --needed "${runtime_packages[@]}"
sed -i '\|^Include = /etc/pacman.d/omartix-installer.conf$|d' "$target/etc/pacman.conf"
rm -f "$target_repository_config"
rm -rf "$target_repository"

configure_limine() {
  local btrfs_uuid cmdline luks_uuid esp_path efi_binary boot_disk efi_number default_template menu_template
  btrfs_uuid=$(blkid -s UUID -o value "$root_device")
  [[ -n $btrfs_uuid ]] || die 'could not read Btrfs UUID'
  if [[ $encrypted == true ]]; then
    luks_uuid=$(blkid -s UUID -o value "$root_partition")
    cmdline="cryptdevice=UUID=$luks_uuid:omarchy_root root=/dev/mapper/omarchy_root zswap.enabled=0 rootflags=subvol=@ rw rootfstype=btrfs"
  else
    cmdline="root=UUID=$btrfs_uuid zswap.enabled=0 rootflags=subvol=@ rw rootfstype=btrfs"
  fi
  esp_path=$(jq -r '.omarchy_install.boot.esp_path // "/EFI/limine"' "$config")
  efi_binary=$(jq -r '.omarchy_install.boot.efi_binary // "limine_x64.efi"' "$config")
  mkdir -p "$target/etc/pacman.d/hooks" "$target/etc/default" "$target/etc/kernel"
  default_template=$target/usr/share/omarchy/install/assets/limine/default.conf
  [[ -r $default_template ]] || default_template=$target/usr/share/omarchy/default/limine/default.conf
  menu_template=$target/usr/share/omarchy/install/assets/limine/limine.conf
  [[ -r $menu_template ]] || menu_template=$target/usr/share/omarchy/default/limine/limine.conf
  [[ -r $default_template && -r $menu_template ]] || die 'Omarchy Limine templates are missing'
  sed -e "s|@@CMDLINE@@|$cmdline|" -e "s|^ESP_PATH=.*|ESP_PATH=\"$boot_mount\"|" "$default_template" >"$target/etc/default/limine"
  printf '%s\n' "$cmdline" >"$target/etc/kernel/cmdline"
  boot_disk=/dev/$(lsblk -ndo PKNAME "$esp_partition")
  efi_number=$(lsblk -ndo PARTN "$esp_partition")
  [[ -b $boot_disk ]] || die 'could not resolve boot disk'
  if [[ -d /sys/firmware/efi ]]; then
    [[ -r $target/usr/share/limine/BOOTX64.EFI && $efi_number =~ ^[0-9]+$ ]] || die 'target Limine EFI files are missing'
    mkdir -p "$target_esp$esp_path"
    cp "$target/usr/share/limine/BOOTX64.EFI" "$target_esp$esp_path/$efi_binary"
    printf '[Trigger]\nOperation = Upgrade\nType = Package\nTarget = limine\n\n[Action]\nDescription = Deploying Omarchy Limine after upgrade...\nWhen = PostTransaction\nExec = /usr/bin/cp /usr/share/limine/BOOTX64.EFI %s/%s\n' "$esp_path" "$efi_binary" >"$target/etc/pacman.d/hooks/99-omarchy-limine.hook"
    cp "$menu_template" "$target_esp/limine.conf"
    while read -r line; do [[ $line =~ ^Boot([0-9A-Fa-f]{4}).*Limine ]] && efibootmgr --bootnum "${BASH_REMATCH[1]}" --delete-bootnum || true; done < <(efibootmgr)
    efibootmgr --create --disk "$boot_disk" --part "$efi_number" --label Limine --loader "\\${esp_path#/}\\$efi_binary" --unicode
  else
    [[ -r $target/usr/share/limine/limine-bios.sys ]] || die 'target Limine BIOS payload is missing'
    mkdir -p "$target/boot/limine"
    cp "$target/usr/share/limine/limine-bios.sys" "$target/boot/limine/limine-bios.sys"
    printf '[Trigger]\nOperation = Upgrade\nType = Package\nTarget = limine\n\n[Action]\nDescription = Deploying Omarchy Limine after upgrade...\nWhen = PostTransaction\nExec = /usr/bin/sh -c "limine bios-install %s && cp /usr/share/limine/limine-bios.sys /boot/limine/limine-bios.sys"\n' "$boot_disk" >"$target/etc/pacman.d/hooks/99-omarchy-limine.hook"
    cp "$menu_template" "$target/boot/limine.conf"
    printf '\nENABLE_UKI=no\nENABLE_LIMINE_FALLBACK=no\n' >>"$target/etc/default/limine"
    artix-chroot "$target" limine bios-install "$boot_disk"
  fi
}
configure_limine

prepare_target_setup() {
  local source destination offline_source=/usr/share/omarchy-iso/artix-repo
  # Keep the installed system's Artix-first pacman.conf. The live ISO uses an
  # offline-only configuration, so copying it here would discard Artix and
  # Arch-extra repositories after the runtime packages were installed.
  cat >"$target/etc/pacman.d/omartix-offline.conf" <<'EOF'
[offline]
SigLevel = Never
Server = file:///var/cache/omarchy/mirror/offline/
EOF
  printf '\nInclude = /etc/pacman.d/omartix-offline.conf\n' >>"$target/etc/pacman.conf"
  # Artix stages the signed ISO mirror under /usr/share rather than the
  # upstream cache path. Bind it at the upstream path inside the target so
  # Omarchy's setup commands consume the same offline contract unchanged.
  [[ -d $offline_source ]] || die "live ISO setup source is missing: $offline_source"
  destination="$target/var/cache/omarchy/mirror/offline"
  mkdir -p "$destination"; mount --bind "$offline_source" "$destination"; setup_mounts+=("$destination")
  source=/opt/packages
  [[ -d $source ]] || die "live ISO setup source is missing: $source"
  destination="$target$source"; mkdir -p "$destination"; mount --bind "$source" "$destination"; setup_mounts+=("$destination")
}
remove_offline_provider() {
  sed -i '\|^Include = /etc/pacman.d/omartix-offline.conf$|d' "$target/etc/pacman.conf"
  rm -f "$target/etc/pacman.d/omartix-offline.conf"
}
read_optional() { [[ -r $1 ]] && command cat -- "$1" || true; }
run_target() {
  local user=$1 command=$2; shift 2
  local -a env=("OMARCHY_PATH=/usr/share/omarchy" "OMARCHY_INSTALL=/usr/share/omarchy/install" "OMARCHY_INSTALL_USER=$username" "OMARCHY_USER_NAME=$(read_optional "$full_name_file")" "OMARCHY_USER_EMAIL=$(read_optional "$email_file")" "OMARCHY_MIRROR=$(read_optional /root/omarchy_mirror)" "OMARTIX_CORE_PACKAGE=$OMARTIX_CORE_PACKAGE" "OMARCHY_NVIM_PACKAGE=$OMARCHY_NVIM_PACKAGE" "OMARCHY_INSTALL_LOG_FILE=/var/log/omarchy-install.log" "OMARCHY_LOG_TO_STDOUT=1")
  # Artix's chroot helper has no -u option. Enter the target as root, then use
  # the target's runuser to drop privileges.
  if [[ -n $user ]]; then artix-chroot "$target" runuser -u "$user" -- env --unset=XDG_RUNTIME_DIR "${env[@]}" "$command" "$@"; else artix-chroot "$target" env --unset=XDG_RUNTIME_DIR "${env[@]}" "$command" "$@"; fi
}
prepare_target_setup
[[ ! -x $target/usr/bin/omarchy-hibernation-setup ]] || run_target '' /usr/bin/omarchy-hibernation-setup --force --no-rebuild
# The dinit port keeps Omarchy's command name so its normal dispatcher and
# scripts remain valid; its implementation sources install/dinit/config/all.sh.
if [[ $defer_provisioning == true ]]; then run_target '' /usr/bin/omarchy-apply-system --defer-provisioning --first-install; else run_target '' /usr/bin/omarchy-apply-system --install-user "$username" --first-install; fi

provision_dir=$target/var/lib/omarchy/provisioning
mkdir -p "$provision_dir/packages"
node_tarball=$(find /opt/packages -maxdepth 1 -type f -name 'node-v*-linux-x64.tar.gz' -print -quit)
[[ -n $node_tarball ]] || die 'bundled Node tarball is missing'
cp "$node_tarball" "$provision_dir/packages/"
# Every encrypted installation needs the mkinitcpio encrypt hook.  Deferred
# provisioning additionally embeds a one-time key for its first boot, but an
# ordinary encrypted installation must still reach the normal LUKS passphrase
# prompt without that key.
if [[ $encrypted == true ]]; then
  mkdir -p "$target/etc/mkinitcpio.conf.d"
  cat >"$target/etc/mkinitcpio.conf.d/99-omarchy-provisioning-encrypt.conf" <<'EOF'
if [[ " ${HOOKS[*]} " != *" encrypt "* ]]; then
  _omartix_encrypt_hooks=()
  _omartix_encrypt_inserted=false
  for _omartix_hook in "${HOOKS[@]}"; do
    _omartix_encrypt_hooks+=("$_omartix_hook")
    if [[ $_omartix_hook == block ]]; then
      _omartix_encrypt_hooks+=(encrypt)
      _omartix_encrypt_inserted=true
    fi
  done
  [[ $_omartix_encrypt_inserted == true ]] || _omartix_encrypt_hooks+=(encrypt)
  HOOKS=("${_omartix_encrypt_hooks[@]}")
  unset _omartix_encrypt_hooks _omartix_encrypt_inserted _omartix_hook
fi
EOF
fi
if [[ $defer_provisioning == true ]]; then
  touch "$provision_dir/pending"
  install -Dm644 "$target/usr/share/omarchy/install/artix/dinit/omarchy-provision-owner" "$target/etc/dinit.d/omarchy-provision-owner"
  enable_dinit omarchy-provision-owner
  if [[ -n ${install_passphrase:-} ]]; then
    printf '%s' "$install_passphrase" >"$provision_dir/luks-key"; chmod 600 "$provision_dir/luks-key"
    install -Dm600 "$provision_dir/luks-key" "$target/etc/omarchy/provisioning.key"
    mkdir -p "$target/etc/limine-entry-tool.d"
    printf 'KERNEL_CMDLINE[default]+=" cryptkey=rootfs:/etc/omarchy/provisioning.key"\n' >"$target/etc/limine-entry-tool.d/99-omarchy-provisioning-unlock.conf"
    printf 'FILES+=(/etc/omarchy/provisioning.key)\n' >"$target/etc/mkinitcpio.conf.d/99-omarchy-provisioning-key.conf"
  fi
fi

info 'finalizing Limine boot images'
artix-chroot "$target" limine-update
[[ $defer_provisioning == true ]] || run_target "$username" /usr/bin/omarchy-provision-user --force --first-install
remove_offline_provider
mkdir -p "$target/etc/sddm.conf.d"
printf '[Theme]\nCurrent=omarchy\n\n[Users]\nRememberLastUser=true\nRememberLastSession=true\n' >"$target/etc/sddm.conf.d/99-omarchy-login.conf"
if [[ $encrypted == true && $defer_provisioning == false ]]; then printf '[Autologin]\nUser=%s\nSession=omarchy.desktop\n' "$username" >"$target/etc/sddm.conf.d/autologin.conf"; fi
rm -f "$target/etc/resolv.conf"

if [[ -n $authorized_keys_file && -r $authorized_keys_file && $defer_provisioning == false ]]; then
  require_command ssh-keygen
  mapfile -t authorized_keys < <(sed '/^[[:space:]]*#/d;/^[[:space:]]*$/d' "$authorized_keys_file")
  (( ${#authorized_keys[@]} > 0 )) || die 'authorized-keys file contains no public keys'
  for authorized_key in "${authorized_keys[@]}"; do
    ssh-keygen -lf /dev/stdin <<<"$authorized_key" >/dev/null 2>&1 || die 'authorized-keys file contains an invalid public key'
  done
  install -d -m700 "$target/home/$username/.ssh"
  printf '%s\n' "${authorized_keys[@]}" >"$target/home/$username/.ssh/authorized_keys"
  chmod 600 "$target/home/$username/.ssh/authorized_keys"
  artix-chroot "$target" chown -R "$username:$username" "/home/$username/.ssh"
  [[ -s $target/home/$username/.ssh/authorized_keys ]] || die 'authorized keys were not written to the target'
  [[ $(stat -c '%a:%U:%G' "$target/home/$username/.ssh") == "700:$username:$username" ]] || die 'authorized-keys directory ownership or mode is invalid'
  [[ $(stat -c '%a:%U:%G' "$target/home/$username/.ssh/authorized_keys") == "600:$username:$username" ]] || die 'authorized-keys file ownership or mode is invalid'
  for authorized_key in "${authorized_keys[@]}"; do
    grep -qxF "$authorized_key" "$target/home/$username/.ssh/authorized_keys" || die 'authorized key verification failed'
  done
  # The home directory is a separate Btrfs subvolume. Ensure sshd cannot start
  # until local.target has mounted it, otherwise StrictModes may reject an
  # otherwise valid authorized_keys file during early boot.
  grep -qxF 'depends-on      = local.target' "$target/etc/dinit.d/sshd" ||
    printf '\ndepends-on      = local.target\n' >>"$target/etc/dinit.d/sshd"
  enable_dinit sshd
  artix-chroot "$target" ufw allow ssh || true
fi

if [[ -n $tailscale_authkey_file && -r $tailscale_authkey_file ]]; then
  mapfile -t tailscale_keys < <(sed '/^[[:space:]]*#/d;/^[[:space:]]*$/d' "$tailscale_authkey_file")
  [[ ${#tailscale_keys[@]} == 1 ]] || die 'Tailscale auth-key file must contain exactly one key'
  [[ -x $target/usr/bin/tailscale ]] || die 'Tailscale was requested but is missing from the target'
  install -d -m700 "$target/etc/tailscale"
  printf '%s\n' "${tailscale_keys[0]}" >"$target/etc/tailscale/authkey"
  chmod 600 "$target/etc/tailscale/authkey"
  cat >"$target/etc/dinit.d/omarchy-tailscale-join" <<'EOF'
type = process
command = /usr/bin/sh -c 'until /usr/bin/tailscale up --auth-key file:/etc/tailscale/authkey; do sleep 15; done; rm -f /etc/tailscale/authkey; rm -f /etc/dinit.d/boot.d/omarchy-tailscale-join'
depends-on = tailscaled
restart = false
EOF
  enable_dinit tailscaled
  enable_dinit omarchy-tailscale-join
  artix-chroot "$target" ufw allow in on tailscale0 || true
fi

[[ -s $target_esp/limine.conf && -s $target/etc/kernel/cmdline && -x $target/usr/bin/limine-update ]] || die 'boot validation failed'
info 'installation complete'
