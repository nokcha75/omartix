#!/bin/bash

# Configure Artix's zramen dinit service with Omarchy's zram policy. The
# package owns this config file, so only turn its commented defaults into active
# values; an administrator's existing active setting always wins.

set -euo pipefail

zramen_config="${OMARTIX_ZRAMEN_CONFIG:-/etc/dinit.d/config/zramen.conf}"

[[ -f $zramen_config ]] || {
  echo "Error: zramen configuration is unavailable: $zramen_config" >&2
  exit 1
}

set_default() {
  local variable="$1"
  local value="$2"

  grep -qE "^${variable}=" "$zramen_config" && return 0

  if grep -qE "^#${variable}=" "$zramen_config"; then
    sed -i -E "s|^#${variable}=.*|${variable}=${value}|" "$zramen_config"
  else
    printf '%s=%s\n' "$variable" "$value" >>"$zramen_config"
  fi
}

set_default ZRAM_COMP_ALGORITHM zstd
set_default ZRAM_PRIORITY 100
set_default ZRAM_SIZE 100
# Keep swapon discard disabled to match the prior generator configuration and
# avoid adding discard semantics on encrypted swap systems.
set_default ZRAMEN_SWAPON_DISCARD none
