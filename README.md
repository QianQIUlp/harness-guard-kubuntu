# harness-guard-kubuntu

Kernel-enforced limits for Claude Code (CLI), Claude Desktop, the Antigravity app and
the Antigravity CLI (`agy`) on one Kubuntu machine (KDE on
Wayland).

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
claude / agy / antigravity / menu entries
  -> root-owned forwarder (~/.local/bin/{claude,agy}, /usr/local/bin/antigravity,
     /usr/lib/claude-desktop/claude-desktop)
  -> /usr/libexec/harness-guard/launcher AGENT (Python, runs as the owner; how to run each
     agent comes from /etc/harness-guard/agents/AGENT.toml)
       allowlisted environment, fetch GitHub token, close inherited descriptors,
       switch itself into the AppArmor profile, verify "(enforce)", set no_new_privs,
       enter a private mount namespace with its own /dev/pts (your other terminals
       don't exist inside), CLIs: bind a private dir over ~/.local/bin for the updater
  -> vendor binary; every child inherits the same profile
```

The profiles also attach by path (`~/.local/share/claude/versions/*`,
`claude-desktop.real`, `~/.local/state/agy/guard-bin/agy` and
`/opt/antigravity/antigravity`), so running a vendor binary directly is still confined.
If the
profile is missing or only complaining, the launcher refuses to start; it never falls
back to running unconfined.

Everything is one Debian package, `harness-guard_VERSION_all.deb`, built by
`tools/build-deb.sh`; dpkg owns every installed file.

| Path | Installed as |
| --- | --- |
| `apparmor/abstractions/harness-guard` | `/etc/apparmor.d/abstractions/harness-guard`: rules shared by every agent guard |
| `apparmor/abstractions/harness-guard-claude` | `/etc/apparmor.d/abstractions/harness-guard-claude`: Claude's own state, shared by both Claude guards |
| `apparmor/harness-guard-launcher` | `/etc/apparmor.d/harness-guard-launcher`: entry profile so a launch from a terminal switches cleanly |
| `apparmor/claude-code-guard` | `/etc/apparmor.d/claude-code-guard` |
| `apparmor/claude-desktop-guard` | `/etc/apparmor.d/claude-desktop-guard`: Desktop GUI, tray, portals, KWallet, Cowork |
| `apparmor/abstractions/harness-guard-electron` | `/etc/apparmor.d/abstractions/harness-guard-electron`: Chromium sandbox, Wayland, GPU, audio, tray, notifications and portals for the Electron apps |
| `apparmor/abstractions/harness-guard-antigravity` | `/etc/apparmor.d/abstractions/harness-guard-antigravity`: settings shared by the Antigravity app and agy (`~/.gemini/config`) |
| `apparmor/agy-guard` | `/etc/apparmor.d/agy-guard` |
| `apparmor/antigravity-guard` | `/etc/apparmor.d/antigravity-guard`: the Antigravity app, its language server and agents |
| `agents/*.toml` | `/etc/harness-guard/agents/`: how the launcher runs each agent |
| `etc/owner.toml` | `/etc/harness-guard/owner.toml`, written once (default in `/usr/share/harness-guard/`): the user, UID and home whose agents are guarded |
| `etc/policy.toml` | `/etc/harness-guard/policy.toml`, written once (default in `/usr/share/harness-guard/`): your path choices per agent |
| `bin/harness-guard` | `/usr/libexec/harness-guard/launcher`: the launcher |
| `bin/harness-guard-handoff`, `etc/systemd/harness-guard-handoff*` | `/usr/libexec/harness-guard/handoff`, started per request by the user socket unit in `/usr/lib/systemd/user`: starts agy in its own guard for Claude |
| `bin/harness-guard-apply` | `/usr/sbin/harness-guard-apply`: compiles the policy into `/etc/apparmor.d/harness-guard/` and reloads the profiles |
| `bin/harness-guard-setup` | `/usr/sbin/harness-guard-setup`: guards and releases agents, with a receipt per agent in `/var/lib/harness-guard/receipts/` |
| `console/` (program, QML, `qmldir`) | `/usr/lib/harness-guard/`, started as `/usr/bin/harness-guard-console` or "Harness Guard" in the menu: the console (below) |
| `console/org.harness-guard.policy` | `/usr/share/polkit-1/actions/`: lets the console run `harness-guard-apply` and `harness-guard-setup` through `pkexec`, admin password every time |
| `tools/check.sh` | also `/usr/libexec/harness-guard/check`, which the console runs |
| `bin/xdg-open`, `bin/bwrap` | `/usr/libexec/harness-guard/bin/` (first in the guarded `PATH`) |
| `etc/gitconfig` | `/etc/harness-guard/gitconfig` |
| `etc/gtk.gschema.override` | compiled into `/etc/harness-guard/gtk-schemas/` |
| `packaging/` | the package's maintainer scripts |

**Guarding an agent** is `harness-guard-setup guard AGENT`: it writes the forwarders,
diverts the packaged Desktop ELF to `claude-desktop.real`, moves the real `agy` to
`~/.local/state/agy/guard-bin/`, points `/usr/local/bin/antigravity` and the
Antigravity menu entry at the launcher, enables the agy hand-off socket, and sets up
Cowork's `vhost_vsock` access. The CLI forwarders `~/.local/bin/{claude,agy}` are
root-owned and immutable (`chattr +i`) so an agent can't replace them with an
unconfined program. Before changing anything it records the original of each thing
it touches (bytes, owner, mode, times, immutable flag, symlink target, diversion,
unit, device ACL) in `/var/lib/harness-guard/receipts/AGENT.json`.
`harness-guard-setup release AGENT` puts exactly that back and deletes the receipt; a
file someone else changed since (a reinstalled menu entry) is left as it is and
reported, and if Claude Code's original version was removed by an update, `claude`
points at the version in use instead. Installing the package guards every agent that
is installed, except ones you released; removing it releases every agent first.
`harness-guard-setup status` lists the receipts, and so does the console's Settings
page, with Guard and Release per agent.

## What Claude can and cannot do

| | Access |
| --- | --- |
| `~/src/**` | read, write, execute (children stay confined); from the policy |
| `~/.agents/skills` | read and execute; from the policy |
| `~/.claude*`, `~/.config/Claude` | read/write (application state) |
| `/usr/**`, NVM v22.23.2, `~/.cargo/bin`, `~/.rustup` | read and execute, no writes |
| Caches and temp | private: `~/.cache/claude-guard`, `/tmp/claude-<uid>` |
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
to open instead of opening the browser. The other guards can't read that folder.

**agy as Claude's subagent.** A guard can never switch into another one (the launcher
sets `no_new_privs`), so Claude can't start agy in `agy-guard` itself. Instead, `agy`
inside Claude's guards (the root-owned forwarder, also placed in Claude Code's private
`~/.local/bin`) runs the launcher, which sees it is inside a guard listed in agy's
`handoff_from` and passes the arguments, the working directory and its pipes to
`harness-guard-handoff` over `/run/user/<uid>/harness-guard-handoff.sock`. That service,
outside the guards, starts `harness-guard agy` exactly as a terminal would, returns the
exit status, and stops agy if the caller goes away. agy runs with its own guard and
login; Claude never gets agy's files. Only Claude's guards can reach the socket, the
service checks the caller's AppArmor label, the working directory must be one the
caller can read, and a terminal is never passed (agy's output must be a pipe or file).

**The Antigravity app** (Electron in `/opt/antigravity`) runs in its own guard, with its
language server, agents, terminals and MCP servers. It gets the same base rules and
policy paths, `~/.config/Antigravity`, `~/.gemini/config` and its own
`~/.gemini/antigravity` (conversations and login). Its browser agent drives hidden
tabs inside the app, so Chrome is not involved. Its language server asks the Secret
Service for its login first; the guard refuses (without logging it, since it happens on
every start), and it keeps the login in its own file in `~/.gemini/antigravity`
instead. Sign in once inside the guard; the sign-in page opens in your normal browser.
The `SSH_CONNECTION` trick used for agy doesn't work here: it switches the app to a
paste-the-code sign-in that the app never shows. Its cookies use Chromium's built-in
key (`--password-store=basic`) instead of KWallet. `/opt/antigravity`
is read-only inside the guard: the app's updater does nothing for this kind of install,
so install new versions as before, outside the guard, then choose "Guard again" in
the console's Settings, or run `sudo harness-guard-setup guard antigravity`
(`check.sh` reports when the command or menu entry no longer uses the launcher). The
app's "install Antigravity IDE" wizard is blocked, because it would write an unguarded
IDE into `~/.local/share`. Your own use of the app is limited to the work areas too.

Claude Code's own bubblewrap sandbox (`sandbox.enabled`) is not supported inside the
guard and must stay disabled. AppArmor enforces the boundary instead. `bin/bwrap`
exists only so that GTK's image loader (Glycin) falls back to unsandboxed decoding,
which is still confined by the guard. Glycin falls back only on that specific namespace error.

## Use

```bash
./install.sh               # build the package from this checkout and apt install it
tools/check.sh             # as the owner, from a normal terminal
./install.sh uninstall     # apt remove: releases every agent, then removes the package
./install.sh purge         # also removes /etc/harness-guard and /var/lib/harness-guard
```

Run `install.sh` as yourself: it builds the package with `fakeroot` and only `apt`
runs through `sudo`, so nothing in this checkout runs as root directly. A release's
`.deb` installs the same way (`sudo apt install ./harness-guard_*_all.deb`, or Discover)
and removes with `sudo apt remove harness-guard`. Quit Claude Code, Claude Desktop,
Antigravity and agy before installing or removing; the package refuses otherwise.
Installing over the old `/usr/local` layout of `install.sh` (before 0.7) first undoes
that layout, so the receipts record the original machine.
**This repository is inside `~/src`, so Claude can edit it. Read `git diff` before every
`./install.sh`**: the package built from it runs as root. Editing this repository
changes nothing until the package is installed. Inside the guard, sudo is denied, so
Claude can propose changes here but cannot apply them.
Removing the package keeps `/etc/harness-guard/{owner,policy}.toml` and the agents you
released by name (in `/var/lib/harness-guard/released/`) until purge; the console's
history in `~/.local/state/harness-guard-console` is yours and stays.

`claude update`, `claude install <version>` and `agy update` work normally. The updaters
write into `~/.local/state/{claude,agy}/guard-bin`, which the launcher shows as
`~/.local/bin`.
Desktop package updates go to the diverted `.real` file and need no action.

**Console:** `harness-guard-console` (PyQt6 + Qt Quick) opens on an overview where
each agent's state is a colour: red is open (not guarded or not enforcing), ink is
running, paper is idle. Each agent has its own page: Start (CLI agents open in Konsole
in a folder you pick) or Stop, its numbers, its reach (the policy paths, edited in
place), what it was refused in the last 24 hours, and its log. Activity follows every
denial live and keeps 30 days of counts; Integrity runs the check and keeps past runs.
Edits collect into a draft across agents. Applying shows the policy and compiled-rule
diff first, then `pkexec` asks for your password and `harness-guard-apply --replace`
installs exactly that text (keeping `policy.toml.bak`), refusing if `policy.toml`
changed since the console read it. Closing the window leaves it in the tray, where it
notifies you when a guard opens, a check starts failing, or an agent is refused
(Settings turns this off, or starts it at login). History and settings are in
`~/.local/state/harness-guard-console`. Start always runs the launcher, never the
agent's entry point, so it fails closed; its error output also goes to the journal
(`journalctl -t harness-guard-AGENT`), and a CLI's window stays open when it fails. The console runs as you, unguarded, offers
no D-Bus or socket API, and refuses to start unless it is the root-owned installed
copy. Settings shows the installed package and each agent's receipt, with Guard
and Release through `pkexec harness-guard-setup`. Activity offers "Allow…" only as a draft entry for review, and never for `~/.*`
paths, since an agent chooses what it gets denied. Activity needs your user to read
the kernel journal (as `check.sh` does).

**Choosing paths per agent:** use the console, or edit the policy and apply it. Running agents get the new
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
- **Claude can direct agy.** Through the hand-off, Claude chooses agy's prompt and
  arguments and uses your agy account. agy can only do what `agy-guard` allows, but
  that includes reading its own login, so a prompt could ask agy to reveal it. A guard
  other than Claude's (the Antigravity app, agy itself) can't start agy at all.
- **Antigravity and agy share `~/.gemini/config`** (MCP servers, plugins, skills), so
  either one can change what the other runs. Both are guarded with the same base rules.
- **Antigravity's browser port.** The app listens on a random localhost port for its
  browser agent (Chrome DevTools protocol, no password). Another local program,
  including another guarded agent that finds the port, could drive the app's pages.
  AppArmor can't filter by port.
- **The Antigravity and agy login files** are readable by unguarded programs, as wallet
  entries are once the wallet is open.
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
