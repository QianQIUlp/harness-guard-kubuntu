# Technical history

This summary preserves operationally relevant changes without reproducing conversation transcripts. Earlier configuration states are superseded by the final sources and validation record.

| Issue | Cause or relevant dependency | Final change |
| --- | --- | --- |
| Desktop startup failures | Missing runtime reads; a later namespace root binding used nodev where a device binding was required | Granted observed runtime dependencies and used the correct device binding |
| Tray integration | Actual plasmashell was itself enforcing; the Chromium menu path differed from generic examples | Used the actual peer label, StatusNotifier interfaces, and `/org/chromium/DbusMenu`; visible tray and Quit verified separately |
| Missing control icons | GTK image decoding used Glycin and nested bwrap; namespace/profile interaction required version-specific analysis | Triggered Glycin 2.1's existing fallback for its exact template, keeping actual decode helpers confined |
| Missing minimize/maximize controls | The memory GSettings backend selected the default `menu:close` layout | Installed dedicated compiled GTK defaults with `:minimize,maximize,close` |
| CLI updates disabled | Earlier policy denied native staging/state writes and protected the host launcher without a native activation view | Restored official update paths and a private native bin view; immutable host forwarder retained |
| Version activation | Selecting the highest numeric ELF did not honor the official installer's selected version | Read the vendor-managed private selection link and tested numeric version switches |
| Desktop-to-CLI calls | Forced profile conversion and environment cleanup broke inherited SDK IPC | Kept the existing guard and inherited environment for already-confined children |
| Inner developer sandboxes | An outer stock bwrap path stripped capabilities needed by later namespace setup | Used installed unshare/BusyBox for the trusted view and cleared temporary capabilities before app execution |
| Startup toggle | Native autostart writes conflicted with a trusted host entry; an owner rule alone did not prevent rename replacement | Persistent private autostart data plus an immutable root entry whose Exec is fixed |
| Java/Rust/pnpm failures | Toolchains, Corepack dependency paths, Rustup settings locks, and PTY/public initialization reads were incomplete | Shared read/execute developer rules, private writable caches, settings lock and PTY access; actual compilation and preview tested |
| GitHub authentication | Guarded helpers could not use the existing desktop credential path | Trusted entry retrieves the existing GitHub token; guarded processes use native gh and Git HTTPS helper |
| Cowork device access | vhost_vsock was not loaded and qiu lacked device permissions | Authorized persistent module loading and UID 1000 ACL; device access checked |

Relevant lessons: identify the actual layer before changing a profile; check complete affected interactions rather than interface registration alone; preserve parent confinement in helpers; batch related changes; and reuse unchanged verification. Historical synthetic executable probes and repeated account calls are not needed for maintenance.

## Reference and backup stages

Original local backups are `20261005-223650` (CLI), `desktop-20261005-235542` (Desktop), and `finish-20261006-114104` (before the dedicated GTK defaults). Later repair, native-update, directory-view, startup-state, and developer-tool stages remain under `/var/backups/claude-guard/`.

The main developer-tool change was backed up as `devtools-20261006-201908`; subsequent dependency adjustments used `devtools-20261006-202359`, `devtools-20261006-202824`, and `devtools-20261006-203418`. Backup manifests were synchronized to the current entries and integration files. Their original package fields are archival metadata.

Context7 was used for the relevant AppArmor, GLib/GTK, Glycin, Electron, Portal, Claude Code, Corepack/Cargo, PTY, GitHub CLI, and Docker questions. Where documentation coverage was insufficient, local policy and version-matched implementation checks supplied the missing evidence. Public references and upstream licenses are listed in THIRD_PARTY.md.
