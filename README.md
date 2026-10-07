# harness-guard-kubuntu

Kernel-enforced limits for Claude Code (CLI) and Claude Desktop on one Kubuntu machine
(`tele`, user `qiu`, UID 1000, KDE on Wayland).

The models can't be trusted to restrict themselves, so the limits live outside them, in
AppArmor. The guard has three goals:

- **Keep private data private.** SSH/GPG keys, cloud and browser credentials, the wallet,
  shell history, and everything in `$HOME` outside the work areas are unreadable.
- **No escape.** The guard can't be turned off or bypassed from inside it: no sudo/setuid,
  no Docker socket, no access to policy files, and no files planted where an
  unguarded program (shell startup, autostart, shared caches, the `claude` entry
  itself) would later execute them.
- **Stay useful.** Development tools, GitHub, vendor updates, and the Desktop GUI
  (tray, window buttons, notifications, Cowork) keep working.
- **Nothing starts by itself.** Claude never autostarts at login; it can't write
  `~/.config/autostart` or systemd user units.

## How it works

```text
claude / Desktop menu
  -> root-owned forwarder (~/.local/bin/claude, /usr/lib/claude-desktop/claude-desktop)
  -> /usr/local/libexec/claude-guard (Python, runs as qiu)
       allowlisted environment, fetch GitHub token, close inherited descriptors,
       switch itself into the AppArmor profile, verify "(enforce)", set no_new_privs,
       enter a private mount namespace with its own /dev/pts (your other terminals
       don't exist inside), CLI: bind a private dir over ~/.local/bin for the updater
  -> vendor binary; every child inherits the same profile
```

The profiles also attach by path (`~/.local/share/claude/versions/*` and
`claude-desktop.real`), so running a vendor binary directly is still confined. If the
profile is missing or only complaining, the launcher refuses to start; it never falls
back to running unconfined.

| Path | Installed as |
| --- | --- |
| `apparmor/abstractions/claude-guard` | `/etc/apparmor.d/abstractions/claude-guard`: rules shared by both guards |
| `apparmor/claude-guard-launcher` | `/etc/apparmor.d/claude-guard-launcher`: entry profile so a launch from a terminal switches cleanly |
| `apparmor/claude-code-guard` | `/etc/apparmor.d/claude-code-guard` |
| `apparmor/claude-desktop-guard` | `/etc/apparmor.d/claude-desktop-guard`: Desktop GUI, tray, portals, KWallet, Cowork |
| `bin/claude-guard` | `/usr/local/libexec/claude-guard` |
| `bin/xdg-open`, `bin/bwrap` | `/usr/local/libexec/claude-guard-bin/` (first in the guarded `PATH`) |
| `etc/gitconfig` | `/etc/claude-guard/gitconfig` |
| `etc/gtk.gschema.override` | compiled into `/etc/claude-guard/gtk-schemas/` |

`install.sh` also writes the two forwarders, keeps the packaged Desktop ELF diverted to
`claude-desktop.real`, and sets up Cowork's `vhost_vsock` access. The CLI forwarder
`~/.local/bin/claude` is root-owned and immutable (`chattr +i`) so Claude can't replace
it with an unconfined program; `install.sh uninstall` removes it.

## What Claude can and cannot do

| | Access |
| --- | --- |
| `~/src/**` | read, write, execute (children stay confined) |
| `~/.claude*`, `~/.config/Claude` | read/write (application state) |
| `~/.agents/skills` | read and execute |
| `/usr/**`, NVM v22.23.2, `~/.cargo/bin`, `~/.rustup` | read and execute, no writes |
| Caches and temp | private: `~/.cache/claude-guard`, `/tmp/claude-1000` |
| GitHub | the launcher passes `GH_TOKEN` (from `gh auth token`); `gh` and git HTTPS use it |
| Network | unrestricted TCP/UDP |
| Desktop session | Wayland, audio, notifications, tray, URI/file-chooser/settings/shortcut portals |
| KWallet | open the wallet and `readPassword` only (see limits) |
| **Denied** | autostart and systemd user units; the rest of `$HOME`, including `~/.ssh`, `~/.gnupg`, cloud/browser/proxy configs, `~/.config/gh`, `~/.gitconfig`, and shell history; writes to shell startup files; sudo/su/pkexec; Docker/containerd sockets; other D-Bus services (systemd, Secret Service, ...) |

Claude Code's own bubblewrap sandbox (`sandbox.enabled`) is not supported inside the
guard and must stay disabled. AppArmor enforces the boundary instead. `bin/bwrap`
exists only so that GTK's image loader (Glycin) falls back to unsandboxed decoding,
which is still confined by the guard. Glycin falls back only on that specific namespace error.

## Use

```bash
sudo ./install.sh          # install, or apply changes from this repository
tools/check.sh             # as qiu, from a normal terminal
sudo ./install.sh uninstall
```

Quit Claude Code and Claude Desktop before installing; the script refuses otherwise.
**This repository is inside `~/src`, so Claude can edit it. Read `git diff` before every
`sudo ./install.sh`**: that is the one moment Claude-written code runs as root.
Editing this repository changes nothing until `install.sh` runs. Inside the guard,
sudo is denied, so Claude can propose changes here but cannot apply them.

`claude update` and `claude install <version>` work normally. The updater writes its
link into `~/.local/state/claude/guard-bin`, which the launcher shows as `~/.local/bin`.
Desktop package updates go to the diverted `.real` file and need no action.

**Adding a work area outside `~/src`:** add `owner /path/ r,` and `owner /path/** rwkmix,`
to `apparmor/abstractions/claude-guard`, then run `install.sh`.
**New Node version:** change the NVM path in the abstraction and `NODE` in
`bin/claude-guard`.

## Accepted limits

- **Work areas are writable.** Code that Claude writes in `~/src` runs unconfined when
  an unguarded program acts on it: git hooks and repo config (`core.fsmonitor`,
  `core.hooksPath`, filters) on your next `git status`, `package.json` scripts,
  Makefiles, and editor tasks in VS Code, Kiro or Antigravity. Review changes before
  running them outside the guard, and keep those editors' workspace trust prompts on.
- **Network is not filtered.** Anything Claude can read can be sent anywhere. That is
  why the read boundary matters.
- **GitHub credentials are deliberately available** to the guarded processes.
- **KWallet `readPassword`** can't be limited to Claude's own entries, so Desktop can
  read any password entry once the wallet is open. Wallet writes and other read methods
  are denied.
- **Wayland clipboard:** a focused window can read the clipboard.
- **Other processes' command lines are visible** (`/proc/*/cmdline`; environments,
  memory and signals are not). Keep secrets out of command-line arguments. A private
  PID namespace would hide them but breaks IDE integration, which checks IDE PIDs.
- **Links and files open in your normal apps, unguarded** (through the desktop portal).
  Web links, folders and file types with a single handler open without a chooser;
  that includes other agents' URL schemes (`codex://`, `kiro://`, `grokbot://`), which
  start those agents unguarded.
- **Desktop audio:** Desktop can use the microphone (PipeWire/Pulse) for voice input.
- **Attachments from outside the work areas** (Downloads, Documents, ...) can't be read
  by Desktop even when picked in the file chooser; copy them into `~/src` first.
