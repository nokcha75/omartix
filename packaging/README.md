# Packaging Omartix from this repository

Omartix keeps its source, dinit port, package recipe, tests, and future
publication automation in one repository. No application-specific Omartix
package repository is planned.

## Scope

`packaging/omartix/PKGBUILD` produces the one distribution-specific payload:
the Omarchy commands, defaults, migrations, and Artix+dinit service assets
that cannot safely coexist with the upstream `omarchy` and
`omarchy-settings` packages. It replaces that core pair when it is eventually
enabled for an Omartix installation.

All other packages remain external dependencies:

- Artix `system`, `world`, and `galaxy` are preferred.
- The audited Arch `extra` compatibility list is used only for applications
  without an init, driver, or core-library role.
- Omarchy's signed repository remains usable for compatible Omarchy packages.

## Build and publication boundary

The recipe intentionally requires `OMARTIX_SRC`, so a release job builds the
exact checked-out commit rather than downloading mutable source during a
package build:

```bash
OMARTIX_SRC="$PWD" OMARTIX_PACKAGE_VERSION=0.1.0 makepkg --syncdeps --cleanbuild
```

The release job will sign the resulting package database and publish it to a
provider selected later. GitHub Pages, Cloudflare R2, or another HTTPS static
host all use the same `stable/<arch>`, `rc/<arch>`, and `edge/<arch>` layout.
Host-specific URLs, signing fingerprints, and keyring package names are not
hard-coded in this recipe.

Until that remote channel exists, the installer keeps using Omarchy's current
signed supplementary repository. The dinit repository finalizer can already
persist a complete alternative trust tuple when an Omartix channel is ready.

## Init-system boundary

The source tree retains some upstream `systemd` and UWSM defaults so upstream
merges remain reviewable. They are not part of the published Omartix package:
the package recipe removes `default/systemd`, `default/uwsm`, and
`/etc/systemd`, while dinit and elogind own the installed system and session
lifecycle. The same substitution applies to `omarchy-upgrade-to-quattro`, the keyring
helper, Limine `BOOT_ORDER`, and the ISO package/hardware lists: the tree keeps
the upstream files, and the package installs the Artix copies from
`install/artix/` and `bin/omartix-update-keyring`.

Two legacy migrations still mention systemd only to identify and remove
unsafe files left by retired upstream installers. They never start or manage
systemd. The package test treats those two cleanup migrations as an explicit
allowlist, so a future systemd-specific migration requires an Omartix port or
an intentional review before it can be released.

## Local ISO development

Building a package from an uncommitted checkout is permitted only for local
development and ISO smoke tests. It is not a release path and must never be
presented as an update channel for installed systems.
