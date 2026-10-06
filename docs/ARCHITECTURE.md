# Architecture and permission boundaries

## Environment

Recorded host: `tele`, user `qiu`, UID 1000, Kubuntu/KDE on Wayland. Packaging inspection found Ubuntu 26.04.1, kernel 7.0.0-38-generic, AppArmor 5.0.2, GLib 2.88.0, GTK 3.24.52, Glycin 2.1.5, and bubblewrap 0.11.1. The recorded CLI version is 2.1.291; the Desktop package is 2.19675.1.

## Execution path

```text
Normal entry point
  -> root-owned Python -I launcher
  -> external environment and descriptor cleanup
  -> no_new_privs and AppArmor enforce
  -> private update/autostart directory view
  -> clear temporary inherited/ambient capabilities
  -> native Claude/Electron and confined children
```

The vendor application is unchanged. Global AppArmor and Chromium's own sandbox remain enabled. Missing enforcement causes launch failure rather than an unconfined fallback. Effective process labels, NNP, and capabilities were checked on native processes.

| Repository source | Installed target or role |
| --- | --- |
| `files/claude-entry` | `/home/qiu/.local/bin/claude`: root-owned immutable Python forwarding file |
| `files/claude-code-launch.py` | `/usr/local/libexec/claude-code-guard`: CLI entry and shared environment/view helpers |
| `files/claude-code-guard-v4.profile` | `/etc/apparmor.d/claude-code-guard`: native CLI `versions/*` attachment |
| `files/claude-desktop-launch.py` | `/usr/lib/claude-desktop/claude-desktop`: trusted Desktop entry |
| `files/claude-desktop-guard.profile` | `/etc/apparmor.d/claude-desktop-guard`: diverted `.real` executable attachment |
| `files/abstractions/*` | `/etc/apparmor.d/abstractions/`: shared developer and namespace rules |
| `files/bwrap`, `files/xdg-open` | `/usr/local/libexec/claude-guard-bin/`: Glycin compatibility and native URI portal |
| `files/gitconfig`, `files/npmrc` | `/etc/claude-code-guard/`: guard-specific tool configuration |
| `files/gtk-schemas/` | Compiled into `/etc/claude-desktop-guard/gtk-schemas/gschemas.compiled` |
| `files/claude-autostart.desktop` | `/home/qiu/.config/autostart/claude-desktop.real.desktop`: immutable host startup entry |
| `files/claude-cowork.conf` | `/etc/modules-load.d/claude-cowork.conf` |
| `files/70-claude-vhost-vsock.rules` | `/etc/udev/rules.d/70-claude-vhost-vsock.rules` |

Desktop imports the installed CLI helper. Changes to shared environment handling, paths, GitHub credential setup, or directory views affect both clients. Already-confined CLI/Desktop children retain inherited environment and SDK IPC instead of forcing a cross-profile transition.

## Native updates and startup

The CLI uses the official updater and version installer. Its native selection link is `/home/qiu/.local/state/claude/guard-bin/claude`. The trusted launcher binds that directory over `.local/bin` in a private namespace using installed `setpriv`, `unshare`, and `busybox-static`. The installer can atomically replace its native link while the host forwarding file remains immutable. Temporary namespace capabilities are cleared before running the application.

The selected link must resolve to a regular executable numeric version in `/home/qiu/.local/share/claude/versions/`. Official updates and explicit numeric version activation were tested. Channel resolution remains the vendor installer's responsibility.

Desktop's dpkg-managed ELF is diverted with a LOCAL diversion to `/usr/lib/claude-desktop/claude-desktop.real`. The original path contains the trusted launcher. `/usr/bin/claude-desktop`, KDE menu entries, URI handling, and the vendor compatibility profile are retained. One actual package update and reboot were verified with this layout. Diverting a generated profile would not intercept maintainer scripts that directly rewrite it.

Desktop's native startup toggle writes its private view in `/home/qiu/.config/Claude/guard-autostart/`. The host root-owned immutable entry always invokes the trusted launcher with `--startup`. The launcher reads enabled/disabled state and ignores the private record's `Exec`. Keeping this state under application configuration avoids losing it during cache cleanup.

## Files and development tools

| Resource | Current access |
| --- | --- |
| `/home/qiu/src/**` | User-owned development files: read, write, build, execute; children inherit confinement |
| `.claude/`, `.claude.json`, Desktop `.config/Claude/` | Application state according to each profile's purpose |
| `.agents/skills/**` | Read, map, and inherited execution; no blanket `.agents` or `.codex` access |
| `/usr/**` | `rmix`: public tools/libraries with inherited confinement, without writes |
| NVM | v22.23.2 and its dependency tree; other versions are not automatically allowed |
| Rust | Read/execute `.cargo/bin` and `.rustup`, settings lock permission, private writable CARGO_HOME |
| npm/pnpm | Public registry configuration readable, private caches writable, personal `.npmrc` not writable |
| GitHub | Existing credentials explicitly permitted; native gh retrieves a token before confinement and passes it in the environment; Git HTTPS uses gh |
| Other credentials | SSH Agent, private cloud/browser stores, and migration service keys remain unavailable |
| Docker/Containerd | Client version queries work; host root service sockets remain denied |

Interpreters and compilers do not bypass the AppArmor file boundary. The Java/Rust/pnpm/PTY tests also checked synthetic private-file denial and Docker denial. Go/Ruby were not installed and no installation was requested.

The conversation terminal requires the root-owned `/dev/ptmx` multiplexer, user PTY slaves, and public Bash initialization reads. The repair did not change global devpts permissions. The private migration credential script can still produce a startup warning without preventing the shell from opening.

## Desktop dependencies

- **Window controls:** the memory GSettings backend avoids user dconf; dedicated compiled defaults set `button-layout` to `:minimize,maximize,close` without changing global KDE settings.
- **Image decoding:** the small bwrap adapter recognizes Glycin 2.1's specific template and triggers its existing fallback. SVG helpers still inherit the main enforcing guard. Other bwrap calls use the native executable.
- **Tray and Quit:** StatusNotifier and `/org/chromium/DbusMenu` rules account for the actual `plasmashell` label. Backend registration and visible rendering are separate checks.
- **Desktop services:** required Wayland access and restricted Settings, OpenURI, FileChooser, GlobalShortcuts, Request/Session, and application registration interfaces. CLI has narrow URI-dispatch D-Bus access, not general wallet or audio access.
- **Audio:** session Pulse/PipeWire access uses a private cookie rather than reading the shared Pulse cookie.
- **Cowork:** packaged helpers, virtiofsd, KVM, and vhost-vsock device access are available. Persistent module loading and UID 1000 rw ACL are installed; a complete VM task was not validated.

## Accepted exceptions and limits

KWallet `readPassword` cannot be restricted by message-body folder/key/application values to Claude entries alone. Shared password-entry reads are an accepted exception. Wallet writes and other read interfaces remain denied. The existing encryption key works; initialization after key loss or replacement has no additional write authorization.

The vendor MCP sensitive-configuration code contains an exception path that can persist original values when encryption is unavailable, encryption fails, or manifest parsing fails. The implementation was left unchanged. There is no evidence of a current trigger. Wallet write restrictions could affect future missing-key initialization; this is not a guarantee that every vendor failure path persists encrypted data.

GitHub credentials are deliberately accessible to the guarded application. Ordinary network access is not domain-isolated. Files in authorized workspaces can be modified. A script later executed by the user in a normal terminal generally does not inherit the guard. Focused Wayland clients retain clipboard-offer protocol capability. File restrictions therefore do not imply complete account, desktop, or network-data isolation.
