# Contributing to Omartix

Omartix is an Omarchy fork for Artix with dinit and elogind. Keep changes
small, focused, and tested.

Before changing a system service, hardware integration, install flow, or
migration, read [the dinit compatibility policy](docs/dinit-compatibility.md).
Use an Artix-maintained dinit companion package where one exists. Do not add a
systemd-only active path.

If an upstream Omarchy feature cannot yet be supported on Artix+dinit, record
the omission's user-visible impact and a concrete restoration condition in that
policy, then add a focused regression test. This makes omissions reviewable and
keeps them visible during upstream rebases.

Run the focused tests for your change before opening a pull request. The full
non-graphical suite is:

```bash
./test/all
```
