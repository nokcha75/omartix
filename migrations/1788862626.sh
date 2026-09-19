#!/bin/bash

set -euo pipefail

echo "Skip the unsupported Elgato Cam Link relay"

# See docs/dinit-compatibility.md. Artix provides neither v4l2-relayd nor a
# dinit service for its udev-triggered relay model, so Omartix deliberately
# leaves the capture device alone rather than shipping an unmaintained wrapper.
