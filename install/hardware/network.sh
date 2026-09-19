#!/bin/bash

# NetworkManager is the sole network manager on Omartix. Its Artix dinit
# definition is enabled during finalization, after all packages are installed.
# There is no legacy network-manager state to retire in a clean dinit install.
