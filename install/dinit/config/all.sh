# shellcheck shell=bash
# Omartix finalization deliberately keeps Omarchy's non-init configuration
# steps, while replacing only the systemd-owned service setup.

run_logged "$OMARCHY_INSTALL/config/theme-system.sh"
run_logged "$OMARCHY_INSTALL/config/browser-policy.sh"
run_logged "$OMARCHY_INSTALL/config/increase-lockout-limit.sh"
run_logged "$OMARCHY_INSTALL/config/lockscreen-pam.sh"
run_logged "$OMARCHY_INSTALL/config/fix-powerprofilesctl-shebang.sh"
run_logged "$OMARCHY_INSTALL/config/ssh-command-path.sh"
run_logged "$OMARCHY_INSTALL/config/ssh-keepalive.sh"
run_logged "$OMARCHY_INSTALL/config/docker.sh"
run_logged "$OMARCHY_INSTALL/dinit/config/omarchy-package-repository.sh"
run_logged "$OMARCHY_INSTALL/dinit/config/earlyoom.sh"
run_logged "$OMARCHY_INSTALL/dinit/config/zram.sh"
run_logged "$OMARCHY_INSTALL/dinit/config/enable-services.sh"
run_logged "$OMARCHY_INSTALL/dinit/config/snapper.sh"
run_logged "$OMARCHY_INSTALL/dinit/config/firewall.sh"
