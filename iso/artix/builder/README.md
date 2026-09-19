# Artix+dinit ISO builder

This directory is the complete Artix ISO source for Omartix. A fresh clone of
the Omartix repository contains the live profile, installer backend, local
package recipes, and unit/KVM acceptance tests. It does not require a sibling
checkout such as `omartix-pkgs` or a private development path.

## Build host

Build on x86_64 Artix with the official `system`, `world`, and `galaxy`
repositories enabled:

```sh
sudo pacman -Syu --needed artix-keyring artix-mirrorlist artools-base artools-iso
iso/artix/builder/check-build-environment.sh
```

`artools-iso` provides `buildiso`; `artools-base` provides the target
installer tools (`basestrap`, `fstabgen`, and `artix-chroot`). The v1 target
uses dinit and elogind, never systemd.

## Fresh-clone handoff

The Omartix checkout itself is the handoff unit: clone it at the intended
commit, install the documented Artix build-host dependencies, and provide a
local signing key. No sibling source checkout is required.

## Fresh-clone build

From the Omartix repository root, use an available private signing key for
the short-lived offline repository embedded in the ISO:

```sh
OMARCHY_ARTIX_GPG_KEY=YOUR_KEY_FINGERPRINT \
  iso/artix/build.sh
```

The default generated paths are `iso/artix/artools-workspace/` and
`iso/artix/iso-output/`; both are ignored. To put build artifacts elsewhere,
pass the workspace and output paths explicitly:

```sh
OMARCHY_ARTIX_GPG_KEY=YOUR_KEY_FINGERPRINT \
  iso/artix/build.sh "$PWD/.artools-workspace" "$PWD/iso-output"
```

The signing key is local build input and is never committed. The resulting
ISO embeds only its public key, signed database, and signed packages.

## Build inputs and trust boundary

- Artix base packages come from a single HTTPS Artix mirror selected by
  `OMARCHY_ARTIX_MIRROR` (or the documented default).
- Published Omarchy runtime packages are copied from `pkgs.omarchy.org` into
  the ISO's offline repository and remain signature-verified.
- The Omartix package and the Artix-specific Limine hook are built from this
  checkout (`packaging/omartix/PKGBUILD`) and signed into that offline
  repository.
- Node is pinned to a version and SHA-256 in `prepare-profile.sh`; override
  all three `OMARCHY_ARTIX_NODE_*` values together only for deliberate
  maintenance updates.

No local package-development tree is read by the Artix path.

## Faster local rebuilds

After a successful full build, reuse the verified repository when changing
only profile files:

```sh
OMARCHY_ARTIX_REUSE_BOOT_REPO=1 iso/artix/build.sh
```

When only Omartix runtime sources changed, retain the verified Limine package
but rebuild and sign `omartix` plus the repository database:

```sh
OMARCHY_ARTIX_REUSE_LIMINE_PACKAGE=1 \
OMARCHY_ARTIX_GPG_KEY=YOUR_KEY_FINGERPRINT \
  iso/artix/build.sh
```

Do not use either mode after changing the Limine package recipe or package
providers.

## Verification

Run source-only tests:

```sh
iso/artix/test/all
```

For KVM acceptance, first check host requirements, then install and boot the
produced ISO in an encrypted VM fixture:

```sh
iso/artix/builder/check-vm-environment.sh
iso/artix/test/integration iso/artix/iso-output/omarchy-artix/artix-omarchy-artix-dinit-YYYYMMDD-x86_64.iso installer-smoke --no-preview
```

The smoke test verifies dinit as PID 1, LUKS root unlock, the Omartix package,
and the enabled dinit NetworkManager service. Keep the ISO checksum and the
test artifacts with a release record.
