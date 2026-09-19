# Omartix dinit compatibility

Omartix preserves Omarchy's user experience where the required component has
an Artix+dinit-supported implementation. This document records deliberate
exceptions so they are visible during maintenance and upstream rebases.

## Omitted features

| Feature | Status | Reason | Revisit when |
| --- | --- | --- | --- |
| Elgato Cam Link 4K automatic 16:9 virtual-camera relay | Not installed | Omarchy's implementation depends on `v4l2-relayd` plus udev-triggered systemd units. Artix currently provides neither `v4l2-relayd` nor a maintained dinit companion service. Omartix leaves the physical capture device available rather than shipping an unmaintained wrapper. | Artix packages `v4l2-relayd` with a dinit service, or upstream supports a supervisor-neutral activation path. |
| ASUS hybrid-GPU mode switching | Hidden from the Hardware menu | Omarchy relies on `supergfxctl`/`supergfxd`, systemd sleep hooks, and a systemd service override. Artix currently provides no `supergfxctl` package or maintained dinit service, so enabling the menu would offer a non-functional GPU transition. | Artix packages `supergfxctl` with a reviewed dinit service and the transition is verified on supported ASUS hybrid-GPU hardware, including suspend/resume. |
| Intel Low Power Mode Daemon (LPMD) | Not installed | Artix has no maintained `intel-lpmd` dinit service. Installing an Arch-oriented daemon without a supervisor would leave it inactive; Omartix uses its `tlp`/`tlp-pd` power-management path instead. | Artix packages `intel-lpmd` with a maintained dinit service and it is verified on supported Intel laptop hardware. |
| Apple T2 MacBook support stack | Not installed | Artix currently packages neither the `linux-t2` kernel stack nor a maintained `t2fanrd` dinit service. A partial install would fail in pacman and leave essential T2 hardware support incomplete. | Artix packages the complete T2 kernel, firmware, audio, and fan-control stack with a reviewed dinit service; verify installation and suspend/resume on supported T2 hardware. |
| Intel Panther Lake special kernel | Not installed | Omarchy quattro now defaults to `linux-omarchy` and dropped the installer `linux-ptl` path. Neither kernel is an Artix package. Omartix stays on Artix `linux` rather than shipping an unreviewed extra kernel; Dell XPS Panther Lake therefore boots the stock Artix kernel until a reviewed Artix kernel with the required display and audio patches is available. | Artix or Omartix publishes a reviewed Panther Lake kernel with matching headers, and install plus suspend/resume are verified on supported XPS hardware. |
| NordVPN | Hidden from the Install menu | Artix currently provides neither `nordvpn-bin` nor a maintained `nordvpnd` dinit service. The original installer would therefore fail after offering the feature. | Artix packages NordVPN with a reviewed dinit service and login/connect/disconnect are verified. |
| GVFS FUSE pre-suspend workaround | Not installed | Omarchy's hook lazily unmounts `gvfsd-fuse` before sleep, then restarts the user GVFS daemon with `systemctl --user` after wake. Artix elogind provides sleep hooks, but this user-session restart flow has no maintained dinit equivalent yet. Normal suspend and hibernation remain available; only the workaround for affected GVFS mounts is absent. | A supervisor-neutral GVFS restart path is implemented and verified through suspend/hibernate with a GVFS FUSE mount. |
| `omarchy upgrade to quattro` | Explicitly unavailable | This is a one-time migration for pre-Quattro, systemd-backed Arch Omarchy installations. Omartix is already package-backed and uses Artix repositories plus dinit services; running the legacy migrator would overwrite those choices. Use `omarchy-update` for normal Omartix updates. | A separate, tested migration is needed for a real pre-Quattro Omartix release. |

## Deliberately unported systemd manager policy

The original systemd manager drop-ins for shutdown timeouts, global `NOFILE`
limits, `systemd-oomd`, `systemd-resolved`, Docker boot ordering, CUPS sandbox
properties, and plocate's systemd timer are not installed on Omartix. They are
systemd-specific policy, not portable service definitions. Their active
counterparts are, where applicable, Artix dinit services and configuration:
`earlyoom-dinit`, `zramen-dinit`, NetworkManager plus dnscrypt-proxy, and the
Artix `dockerd` service. Do not recreate these drop-ins under `/etc/systemd`.
Any future dinit-native replacement must state the user-visible benefit and add
a regression test before it is enabled.

## Maintenance rule

Before omitting a systemd-dependent feature, add an entry above with its
user-visible impact and a concrete restoration condition. Remove the entry
only after the replacement is packaged, enabled, and covered by a regression
test.

## Upstream sync

Keep Omarchy paths intact when they next change. Put Artix behavior next to
them, then let the package or installer substitute at publish time:

- `migrations/artix-skip.txt` — skip upstream migrations such as `linux-omarchy`
  instead of rewriting their scripts.
- `install/artix/omarchy-upgrade-to-quattro` — ship the Omartix stub; leave
  `bin/omarchy-upgrade-to-quattro` as the upstream converter for merges.
- `bin/omartix-update-keyring` — Artix key bootstrap; the package installs it
  as `omarchy-update-keyring`.
- `install/artix/omarchy-other.packages` and `install/artix/hardware/all.sh` —
  Artix package and hardware lists; upstream files stay in `install/`.
- `install/artix/omarchy-defaults.conf` — Artix Limine `BOOT_ORDER`; upstream
  `etc/limine-entry-tool.d/omarchy-defaults.conf` stays for merges.
- systemd user units and unused hardware scripts may remain in the tree.
  `packaging/omartix/PKGBUILD` strips systemd/UWSM and publishes the Artix
  substitutions.

Do not resolve the next quattro merge by editing the same upstream file in
place if an Artix-only path can own the difference.
