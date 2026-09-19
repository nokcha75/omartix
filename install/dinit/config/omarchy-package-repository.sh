#!/bin/bash

# Keep Artix's repositories authoritative and add only Omarchy's signed
# application repository. This is intentionally not an Arch mirror.
set -euo pipefail

# The current default remains Omarchy's signed package channel. A future
# Omartix package host can supply this complete trust tuple at install time.
# Post-install pacman setup reloads the saved tuple after it restores Artix's
# standard pacman.conf, so the repository selection survives that restoration.
repository_config=${OMARTIX_PACKAGE_REPOSITORY_CONFIG:-/etc/omartix/package-repository.conf}
if [[ ${OMARTIX_PACKAGE_REPOSITORY_USE_SAVED:-0} == 1 && -r $repository_config ]]; then
  # Written by this script with printf %q and owned by root in installed
  # systems. It contains only the package repository trust tuple below.
  # shellcheck disable=SC1090
  source "$repository_config"
fi
repository_name=${OMARTIX_PACKAGE_REPOSITORY_NAME:-omarchy}
repository_url=${OMARTIX_PACKAGE_REPOSITORY_URL:-https://pkgs.omarchy.org}
signing_fingerprint=${OMARTIX_PACKAGE_SIGNING_FINGERPRINT:-40DFB630FF42BCFFB047046CF0134EE680CAC571}
signing_key_url=${OMARTIX_PACKAGE_SIGNING_KEY_URL:-"https://keys.openpgp.org/vks/v1/by-fingerprint/$signing_fingerprint"}
keyring_package=${OMARTIX_PACKAGE_KEYRING_PACKAGE:-omarchy-keyring}

[[ $repository_name =~ ^[A-Za-z0-9@._-]+$ ]] || {
  echo "Invalid package repository name: $repository_name" >&2
  exit 1
}
[[ $repository_url == https://* ]] || {
  echo "Package repository URL must use HTTPS: $repository_url" >&2
  exit 1
}
[[ $signing_fingerprint =~ ^[A-F0-9]{40}$ ]] || {
  echo "Invalid package signing fingerprint: $signing_fingerprint" >&2
  exit 1
}
[[ $keyring_package =~ ^[A-Za-z0-9@._+:-]+$ ]] || {
  echo "Invalid package keyring name: $keyring_package" >&2
  exit 1
}

case "${OMARCHY_MIRROR:-stable}" in
stable) channel=stable ;;
rc) channel=rc ;;
edge|dev) channel=edge ;;
*)
  echo "Unknown Omarchy package channel: ${OMARCHY_MIRROR}" >&2
  exit 1
  ;;
esac

pacman_conf=/etc/pacman.conf
server="${repository_url%/}/$channel/\$arch"
tmp_conf=
key_file=
tmp_repository_config=

cleanup() {
  [[ -n $tmp_conf ]] && rm -f "$tmp_conf"
  [[ -n $key_file ]] && rm -f "$key_file"
  [[ -n $tmp_repository_config ]] && rm -f "$tmp_repository_config"
  return 0
}
trap cleanup EXIT

# Normalize our small block on every apply. This changes only [omarchy], keeps
# Artix's repository definitions untouched, and lets a stable/rc/edge choice
# take effect on machines that were configured previously.
tmp_conf=$(mktemp "${pacman_conf}.XXXXXX")
awk -v repository_name="$repository_name" -v server="$server" '
  BEGIN { in_repository = 0; wrote_repository = 0 }
  $0 ~ "^[[:space:]]*\\[" repository_name "\\][[:space:]]*$" {
    in_repository = 1
    if (!wrote_repository) {
      print "[" repository_name "]"
      print "Server = " server
      print "SigLevel = Required DatabaseOptional"
      wrote_repository = 1
    }
    next
  }
  /^[[:space:]]*\[[^]]+\][[:space:]]*$/ { in_repository = 0 }
  !in_repository { print }
  END {
    if (!wrote_repository) {
      print ""
      print "[" repository_name "]"
      print "Server = " server
      print "SigLevel = Required DatabaseOptional"
    }
  }
' "$pacman_conf" >"$tmp_conf"
chmod --reference="$pacman_conf" "$tmp_conf"
chown --reference="$pacman_conf" "$tmp_conf"
mv -f "$tmp_conf" "$pacman_conf"
tmp_conf=

install -d -m 0755 "${repository_config%/*}"
tmp_repository_config=$(mktemp "${repository_config}.XXXXXX")
{
  printf 'OMARTIX_PACKAGE_REPOSITORY_NAME=%q\n' "$repository_name"
  printf 'OMARTIX_PACKAGE_REPOSITORY_URL=%q\n' "$repository_url"
  printf 'OMARTIX_PACKAGE_SIGNING_FINGERPRINT=%q\n' "$signing_fingerprint"
  printf 'OMARTIX_PACKAGE_SIGNING_KEY_URL=%q\n' "$signing_key_url"
  printf 'OMARTIX_PACKAGE_KEYRING_PACKAGE=%q\n' "$keyring_package"
} >"$tmp_repository_config"
chmod 0644 "$tmp_repository_config"
mv -f "$tmp_repository_config" "$repository_config"
tmp_repository_config=

if ! pacman-key --list-keys "$signing_fingerprint" >/dev/null 2>&1; then
  command -v curl >/dev/null || {
    echo "curl is required to bootstrap the Omarchy package signing key." >&2
    exit 1
  }

  key_file=$(mktemp)
  curl -fsSL "$signing_key_url" -o "$key_file"
  fingerprint=$(gpg --show-keys --with-colons "$key_file" | awk -F: '$1 == "fpr" { print $10; exit }')
  [[ $fingerprint == "$signing_fingerprint" ]] || {
    echo "Downloaded Omarchy signing key fingerprint did not match." >&2
    exit 1
  }
  pacman-key --add "$key_file"
  pacman-key --lsign-key "$signing_fingerprint"
fi

# This is a deliberately narrow keyring bootstrap transaction. Regular system
# updates remain Artix-owned and are handled by the normal Omartix updater.
pacman -Sy --noconfirm --needed "$keyring_package"
