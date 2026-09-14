# Omartix finalization has its own dinit-only entry point. Do not source the
# upstream config/all.sh: it enables systemd units and configures services that
# do not exist on an Artix dinit target.

run_logged "$OMARCHY_INSTALL/config/theme-system.sh"
run_logged "$OMARCHY_INSTALL/config/browser-policy.sh"
run_logged "$OMARCHY_INSTALL/config/increase-lockout-limit.sh"
run_logged "$OMARCHY_INSTALL/config/lockscreen-pam.sh"
run_logged "$OMARCHY_INSTALL/config/fix-powerprofilesctl-shebang.sh"
run_logged "$OMARCHY_INSTALL/config/ssh-command-path.sh"
run_logged "$OMARCHY_INSTALL/config/ssh-keepalive.sh"
run_logged "$OMARCHY_INSTALL/config/docker.sh"
run_logged "$OMARCHY_INSTALL/dinit/config/snapper.sh"
run_logged "$OMARCHY_INSTALL/dinit/config/firewall.sh"
