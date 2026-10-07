# harness-guard-kubuntu

Kernel-enforced limits for Claude Code (CLI), Claude Desktop and the Antigravity CLI
(`agy`) on one Kubuntu machine
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
claude / agy / Desktop menu
  -> root-owned forwarder (~/.local/bin/{claude,agy}, /usr/lib/claude-desktop/claude-desktop)
  -> /usr/local/libexec/harness-guard AGENT (Python, runs as qiu; how to run each
     agent comes from /etc/harness-guard/agents/AGENT.toml)
       allowlisted environment, fetch GitHub token, close inherited descriptors,
       switch itself into the AppArmor profile, verify "(enforce)", set no_new_privs,
       enter a private mount namespace with its own /dev/pts (your other terminals
       don't exist inside), CLIs: bind a private dir over ~/.local/bin for the updater
  -> vendor binary; every child inherits the same profile
```

The profiles also attach by path (`~/.local/share/claude/versions/*`,
`claude-desktop.real` and `~/.local/state/agy/guard-bin/agy`), so running a vendor binary directly is still confined. If the
profile is missing or only complaining, the launcher refuses to start; it never falls
back to running unconfined.

| Path | Installed as |
| --- | --- |
| `apparmor/abstractions/harness-guard` | `/etc/apparmor.d/abstractions/harness-guard`: rules shared by every agent guard |
| `apparmor/abstractions/harness-guard-claude` | `/etc/apparmor.d/abstractions/harness-guard-claude`: Claude's own state, shared by both Claude guards |
| `apparmor/harness-guard-launcher` | `/etc/apparmor.d/harness-guard-launcher`: entry profile so a launch from a terminal switches cleanly |
| `apparmor/claude-code-guard` | `/etc/apparmor.d/claude-code-guard` |
| `apparmor/claude-desktop-guard` | `/etc/apparmor.d/claude-desktop-guard`: Desktop GUI, tray, portals, KWallet, Cowork |
| `apparmor/abstractions/harness-guard-antigravity` | `/etc/apparmor.d/abstractions/harness-guard-antigravity`: Antigravity's state in `~/.gemini` |
| `apparmor/agy-guard` | `/etc/apparmor.d/agy-guard` |
| `agents/*.toml` | `/etc/harness-guard/agents/`: how the launcher runs each agent |
| `etc/policy.toml` | `/etc/harness-guard/policy.toml`, created once: your path choices per agent |
| `bin/harness-guard` | `/usr/local/libexec/harness-guard`: the launcher |
| `bin/harness-guard-apply` | `/usr/local/sbin/harness-guard-apply`: compiles the policy into `/etc/apparmor.d/harness-guard/` and reloads the profiles |
| `bin/xdg-open`, `bin/bwrap` | `/usr/local/libexec/harness-guard-bin/` (first in the guarded `PATH`) |
| `etc/gitconfig` | `/etc/harness-guard/gitconfig` |
| `etc/gtk.gschema.override` | compiled into `/etc/harness-guard/gtk-schemas/` |

`install.sh` also writes the forwarders, keeps the packaged Desktop ELF diverted to
`claude-desktop.real`, moves the real `agy` to `~/.local/state/agy/guard-bin/`, and sets
up Cowork's `vhost_vsock` access. The CLI forwarders `~/.local/bin/{claude,agy}` are
root-owned and immutable (`chattr +i`) so an agent can't replace them with an
unconfined program; `install.sh uninstall` removes them and puts `agy` back.

## What Claude can and cannot do

| | Access |
| --- | --- |
| `~/src/**` | read, write, execute (children stay confined); from the policy |
| `~/.agents/skills` | read and execute; from the policy |
| `~/.claude*`, `~/.config/Claude` | read/write (application state) |
| `/usr/**`, NVM v22.23.2, `~/.cargo/bin`, `~/.rustup` | read and execute, no writes |
| Caches and temp | private: `~/.cache/claude-guard`, `/tmp/claude-1000` |
| GitHub | the launcher passes `GH_TOKEN` (from `gh auth token`); `gh` and git HTTPS use it |
| Network | unrestricted TCP/UDP |
| Desktop session | Wayland, audio, notifications, tray, URI/file-chooser/settings/shortcut portals |
| KWallet | open the wallet and `readPassword` only (see limits) |
| **Denied** | autostart and systemd user units; the rest of `$HOME`, including `~/.ssh`, `~/.gnupg`, cloud/browser/proxy configs, `~/.config/gh`, `~/.gitconfig`, and shell history; writes to shell startup files; sudo/su/pkexec; Docker/containerd sockets; other D-Bus services (systemd, Secret Service, ...) |

**agy** gets the same base rules and policy paths, plus its own state
(`~/.gemini/config`, `~/.gemini/antigravity-cli`). It never reaches the keyring: the
launcher sets `SSH_CONNECTION`, which makes agy keep its login in
`~/.gemini/antigravity-cli/antigravity-oauth-token` instead of the Secret Service (which
can't be limited to one entry). Sign in once inside the guard; sign-in may show a link
to open instead of opening the browser. The Claude guards can't read that folder.

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

`claude update`, `claude install <version>` and `agy update` work normally. The updaters
write into `~/.local/state/{claude,agy}/guard-bin`, which the launcher shows as
`~/.local/bin`.
Desktop package updates go to the diverted `.real` file and need no action.

**Choosing paths per agent:** edit the policy and apply it. Running agents get the new
rules within a second, without a restart:

```bash
sudo -e /etc/harness-guard/policy.toml
sudo harness-guard-apply
```

Each entry is a directory (ending in `/`) or a single file, with access `none`, `r`,
`rx`, `rw` or `rwx`. `none` wins over any allow, so it carves a folder or file out of a
wider grant. The compiler refuses globs, symlinks, grants covering your whole home
folder, and write access to anything unguarded programs run or read config from
(shell startup files, `~/.local/bin`, autostart, `~/.gitconfig`, `~/.agents`, ...).
Keys, wallets and browser profiles stay denied whatever the policy says.
**New Node version:** change the NVM path in the abstraction and `NODE` in
`bin/harness-guard`.

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
- **Antigravity app not guarded yet.** It reads `~/.gemini/config` (MCP servers,
  plugins), which agy can write, so until the app has its own guard a misled agy could
  plant a command the app later runs unguarded. The app's own agent is unguarded
  too. Guarding the app is the next step.
- **agy's login file** is readable by unguarded programs, as wallet entries are once the
  wallet is open.
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
