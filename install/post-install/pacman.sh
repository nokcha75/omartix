# Configure pacman after package installation completes. Offline target package
# installs use the live ISO's offline pacman.conf until this final restore.
cp -f "$OMARCHY_PATH/default/pacman/pacman-${OMARCHY_MIRROR:-stable}.conf" /etc/pacman.conf
cp -f "$OMARCHY_PATH/default/pacman/mirrorlist-${OMARCHY_MIRROR:-stable}" /etc/pacman.d/mirrorlist

# The default pacman.conf above deliberately restores Artix's normal
# repositories after the ISO's offline bootstrap. Reapply the signed
# supplementary package channel chosen during dinit finalization so a future
# Omartix host can replace the default Omarchy channel without changing this
# installer flow.
OMARTIX_PACKAGE_REPOSITORY_USE_SAVED=1 \
  "$OMARCHY_INSTALL/dinit/config/omarchy-package-repository.sh"

# Wait for CUPS to own the file, the way omarchy-settings does, so pacman does
# not turn the override into a .pacnew during ISO package installation.
if [[ -f $OMARCHY_PATH/etc-overrides/cups-cups-files.conf && -f /etc/cups/cups-files.conf ]]; then
  install -m 0640 -o root -g cups "$OMARCHY_PATH/etc-overrides/cups-cups-files.conf" /etc/cups/cups-files.conf
  rm -f /etc/cups/cups-files.conf.pacnew
fi

# Plymouth owns its daemon configuration. Apply Omartix's theme selection only
# after pacman has installed the owner, avoiding a file-conflict transaction.
if [[ -f $OMARCHY_PATH/etc-overrides/plymouth-plymouthd.conf && -f /etc/plymouth/plymouthd.conf ]]; then
  install -m 0644 -o root -g root "$OMARCHY_PATH/etc-overrides/plymouth-plymouthd.conf" /etc/plymouth/plymouthd.conf
  rm -f /etc/plymouth/plymouthd.conf.pacnew
fi

source "$OMARCHY_INSTALL/hardware/pacman.sh"
