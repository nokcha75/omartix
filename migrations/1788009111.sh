#!/bin/bash

set -euo pipefail

echo "Temporarily remove automatic printer discovery"

machine_marker="${OMARCHY_CUPS_BROWSED_REMOVAL_MARKER:-/var/lib/omarchy/migrations/1788009111}"

[[ ! -e $machine_marker ]] || exit 0
omarchy-pkg-present cups-browsed || exit 0

# Check the full removal transaction before changing the service or queues.
pacman -Rs --print cups-browsed >/dev/null

# Artix has no maintained cups-browsed dinit service. Terminate any legacy or
# manually started process before removing the package that owns it.
sudo pkill -x cups-browsed 2>/dev/null || true

# cups-browsed leaves its implicitclass queues behind when stopped. Remove idle
# discovery queues before removing the backend they require, but leave queues
# with jobs for the user to resolve.
#
# A healthy CUPS server with no configured printers reports this condition on
# stderr and exits 1. Treat that as an empty queue list; every other failure
# keeps the migration pending so it can be retried.
if queue_report=$(LC_ALL=C lpstat -v 2>&1); then
  :
elif [[ $queue_report == "lpstat: No destinations added." ]]; then
  queue_report=""
else
  printf '%s\n' "$queue_report" >&2
  exit 1
fi

generated_queues=$(printf '%s\n' "$queue_report" |
  sed -n 's|^device for \(.*\): implicitclass://.*|\1|p')

while IFS= read -r queue; do
  [[ -n $queue ]] || continue

  if ! reject_error=$(sudo cupsreject -r "Printer discovery has been removed from Omarchy" "$queue" 2>&1); then
    if LC_ALL=C lpstat -p "$queue" >/dev/null 2>&1; then
      printf '%s\n' "$reject_error" >&2
      exit 1
    else
      continue
    fi
  fi

  if job_report=$(LC_ALL=C lpstat -o "$queue" 2>&1); then
    [[ -z $job_report ]] || continue
  elif LC_ALL=C lpstat -p "$queue" >/dev/null 2>&1; then
    printf '%s\n' "$job_report" >&2
    exit 1
  else
    # The queue disappeared after the initial snapshot, which is already the
    # desired state.
    continue
  fi

  if ! delete_error=$(sudo lpadmin -x "$queue" 2>&1); then
    # Treat a concurrent disappearance as success. A queue that still exists
    # means CUPS did not complete the deletion, so retry the migration later.
    if LC_ALL=C lpstat -p "$queue" >/dev/null 2>&1; then
      printf '%s\n' "$delete_error" >&2
      exit 1
    fi
  fi
done <<<"$generated_queues"

omarchy-pkg-drop cups-browsed >/dev/null
sudo install -Dm644 /dev/null "$machine_marker"
