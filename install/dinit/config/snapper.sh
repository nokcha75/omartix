SNAPPER_CONFIG_PATH="${OMARCHY_SNAPPER_CONFIG_PATH:-/etc/snapper/configs/root}"
SNAPPER_CONF_PATH="${OMARCHY_SNAPPER_CONF_PATH:-/etc/conf.d/snapper}"
template="${OMARCHY_SNAPPER_TEMPLATE:-$OMARCHY_PATH/default/snapper/root}"

echo "Configuring Omartix Snapper snapshot retention"

if [[ ! -f $SNAPPER_CONFIG_PATH ]]; then
  mkdir -p "$(dirname "$SNAPPER_CONFIG_PATH")"
  snapper --no-dbus -c root create-config / >/dev/null 2>&1 || snapper -c root create-config / >/dev/null
fi

install -m 0644 "$template" "$SNAPPER_CONFIG_PATH"
mkdir -p "$(dirname "$SNAPPER_CONF_PATH")"
printf '%s\n' 'SNAPPER_CONFIGS="root"' >"$SNAPPER_CONF_PATH"
chmod 0644 "$SNAPPER_CONF_PATH"

cleanup_service=/etc/dinit.d/omarchy-snapper-cleanup
install -Dm644 /dev/stdin "$cleanup_service" <<'SERVICE'
type = process
command = /usr/bin/omarchy-snapper-cleanup
restart = true
restart-delay = 5
SERVICE
install -d /etc/dinit.d/boot.d
ln -sfn ../omarchy-snapper-cleanup /etc/dinit.d/boot.d/omarchy-snapper-cleanup

# limine-snapper-sync itself is package-owned and enabled by the ISO bootstrap.
