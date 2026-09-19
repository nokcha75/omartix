#!/bin/bash

# Enable thermald for Intel laptops (Sandy Bridge and newer)
# Thermald is useful for Intel Sandy Bridge (2nd gen Core, model 42/45) and newer CPUs.

if omarchy-hw-intel; then
  # Check if Sandy Bridge or newer (model >= 42). Sandy Bridge: model 42 (mobile), 45 (desktop)
  cpu_model=$(grep -m1 "^model\s*:" /proc/cpuinfo 2>/dev/null | cut -d: -f2 | tr -d ' ')
  cpu_model=${cpu_model:-0}
  if ((cpu_model >= 42)) && omarchy-battery-present; then
    omarchy-pkg-add thermald thermald-dinit

    dinit_service="${OMARTIX_THERMALD_DINIT_SERVICE:-/etc/dinit.d/thermald}"
    dinit_boot_dir="${OMARTIX_DINIT_BOOT_DIR:-/etc/dinit.d/boot.d}"
    [[ -f $dinit_service ]] || {
      echo "Error: thermald-dinit did not provide $dinit_service" >&2
      exit 1
    }

    sudo install -d -m 0755 "$dinit_boot_dir"
    sudo ln -sfn ../thermald "$dinit_boot_dir/thermald"
  fi
fi
