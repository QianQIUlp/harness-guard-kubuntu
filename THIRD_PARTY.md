# Upstream sources and licenses

Existing upstream attribution is retained. No new repository-wide license is assigned to files with mixed origins.

- AppArmor profiles were adapted using `roddhjav/apparmor.d` commit `f9ee26eb2d44db2a0ae0fd546cdd845f1bb86c2a`. The Desktop profile retains Alexandre Pujol's copyright and `GPL-2.0-only` identifier. See [GPL-2.0](LICENSES/GPL-2.0.txt).
- The two XML files in `files/gtk-schemas/` come from the installed GNOME `gsettings-desktop-schemas` package, copyright 2010 Codethink Limited and Vincent Untz, under `LGPL-2.1-or-later`. The separate local override sets the required button layout. See [LGPL-2.1](LICENSES/LGPL-2.1.txt).
- System AppArmor ABI, tunables, and public abstractions are referenced, not vendored. Runtime dependencies include util-linux, busybox-static, bubblewrap, PyGObject, GTK/Glycin, KDE Portal, and KWallet.
- Vendor Claude binaries, app.asar, extracted JavaScript, credentials, and unrelated private source are not included.

The CLI profile retains some historical comments; current GitHub access is defined by its actual rules and the architecture document. One packaging-only comment was rewritten in English; no runtime rule changed.

## Mechanism references

Context7 results were checked against installed versions and observed behavior. Documentation alone does not establish local acceptance.

- [AppArmor 5.0.2 permission semantics](https://gitlab.com/apparmor/apparmor/-/blob/v5.0.2/parser/apparmor.d.pod)
- [Claude native updates](https://code.claude.com/docs/en/setup#auto-updates)
- [GLib runtime environment](https://github.com/gnome/glib/blob/main/docs/reference/gio/overview.md) and [schema compilation](https://github.com/gnome/glib/blob/main/docs/reference/gio/glib-compile-schemas.rst)
- [GTK 3.24.52 Wayland settings](https://github.com/GNOME/gtk/blob/3.24.52/gdk/wayland/gdkscreen-wayland.c)
- [Glycin 2.1.5 sandbox implementation](https://github.com/GNOME/glycin/blob/2.1.5/glycin/src/sandbox.rs)
- [Corepack](https://github.com/nodejs/corepack/blob/main/README.md), [Cargo Home](https://github.com/rust-lang/cargo/blob/master/doc/book/src/guide/cargo-home.md), and [GitHub CLI](https://github.com/cli/cli)
