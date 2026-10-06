# Operations

These procedures apply to the existing `tele` / `qiu` deployment. Run commands from the repository root. Another host requires adapting the username, UID, paths, versions, desktop session, diversion, and local backup dependencies.

## Normal use and vendor updates

Use the normal `claude` command and KDE Desktop menu entry. Do not use the writable repository launchers as daily entry points.

```bash
claude --version
claude update
```

Explicit version selection uses `claude install <version>`; channels use the official `stable`/`latest` arguments. Native update and numeric activation were tested. Preserve the immutable host entry and existing package diversion. Analyze a different installer before allowing it to replace trusted entry points.

## Inspection and incremental deployment

Edit the relevant source files and review their diff. Installed targets are listed in Architecture. Reuse the existing self-checks:

```bash
python3 -I files/claude-code-launch.py --guard-self-check
python3 -I files/claude-desktop-launch.py --guard-self-check
```

The Desktop self-check imports the currently installed CLI environment helper. Offline AppArmor parsing must search repository abstractions before system includes:

```bash
apparmor_parser -Q -K -I "$PWD/files" -I /etc/apparmor.d -b "$PWD/files" "$PWD/files/claude-code-guard-v4.profile"
apparmor_parser -Q -K -I "$PWD/files" -I /etc/apparmor.d -b "$PWD/files" "$PWD/files/claude-desktop-guard.profile"
```

`-Q` does not load a kernel policy. The include order was verified with a unique temporary preprocessing marker; setting only the base directory while searching system includes first can validate the old installed abstraction instead.

Compile changed GTK defaults in a temporary directory:

```bash
schema_check_dir=$(mktemp -d)
cp files/gtk-schemas/* "$schema_check_dir/"
glib-compile-schemas --strict "$schema_check_dir"
```

Inspect the generated `gschemas.compiled`, install it only when the schema changes, and remove the temporary directory afterward. Do not change personal dconf or global KDE settings.

Use the established incremental deployment procedure rather than a new management framework:

1. Compare changed sources with their installed targets. Do not rewrite or reload unchanged files.
2. With system-write authorization, close clients affected by the change. Save changed targets by full path in a new root-only directory under `/var/backups/claude-guard/`, together with relevant rollback manifests.
3. Use native `install -o root -g root -m 755` for launchers/helpers and mode `644` for profiles/configuration. The host CLI forwarding file and fixed autostart entry are immutable: remove the flag only when changing them and restore it immediately afterward. Preserve the LOCAL ELF diversion.
4. Reload affected guards with `apparmor_parser -r -K` when profiles or shared abstractions change. Shared rules affect both guards. A Desktop schema-only change does not require redeploying CLI. Do not reload Cowork configuration when unchanged.
5. Synchronize rollback metadata: Desktop `wrapper_sha256`, `profile_sha256`, `gtk_schema_sha256`, and relevant `added_files`; update its backup `trusted-launcher.py` if the launcher changes. A CLI forwarding-file change requires its original manifest's `entry_sha256`. The backup's original package version is not the current installed version.
6. Verify directly affected behavior and record its time and scope.

If deployment stops partway through, restore the files already changed and their related manifest/launcher backups, then reload restored policies. Determine the partial state before retrying.

Host root ownership may appear as UID 65534 inside the Codex filesystem sandbox. Bytes and modes can be compared there; ownership should be checked in the normal host environment. Do not interpret user-namespace UID mapping as an ownership change.

## Additional workspaces

Placing a project under `~/src/` needs no policy change. The entire tree is authorized. A checkout at `~/src/harness-guard-kubuntu` is accessible to guarded Claude sessions.

For a directory outside src, such as `/home/qiu/projects/demo`, authorize the actual path and required operations. This example is not currently granted:

1. Add directory/file rules to both profiles. For example, use parent enumeration `owner /home/qiu/projects/ r,`, target directory `owner /home/qiu/projects/demo/ rw,`, and contents `owner /home/qiu/projects/demo/** rwkmix,`. Read-only material needs only the relevant read/map permissions. `ix` preserves confinement during execution. Explicit deny rules override allow rules.
2. If the application uses an inner bwrap developer sandbox, extend the shared sandbox's `/oldroot/` bind-source list and writable `/newroot/` remount destinations. A file allow rule alone does not cover namespace setup.
3. Existing HOME aliases cover `/home/qiu` paths in oldroot/newroot views. Paths outside HOME need matching aliases and bind handling; do not open the whole host root.
4. Both launchers currently validate externally inherited regular standard streams against `/home/qiu/src`. Extend that check if redirecting CLI input/output or preserving Desktop file logs in the new workspace is required.
5. Parse the policies, compare the actual changes, deploy within authorization, and check the new directory, the required developer sandbox, and denial of an unrelated synthetic private file. Reuse unrelated GUI/login evidence.

There is no separate permission manager. Maintain the existing policy and launcher files rather than introducing another configuration layer.

## Development-tool changes

`files/abstractions/claude-guard-devtools` is shared by both profiles. Public `/usr` tools do not need individual executable grants. A new NVM version requires coordinated changes to `CLAUDE_NODE` in both profiles, `NODE` in the CLI helper, and namespace tool bind sources.

Inspect the installed tool's execution chain, caches, and configuration before granting access. Keep writable build caches separate from read-only toolchains. Installing Go/Ruby is a separate operation; opening a language tool does not require host Docker or unrelated credentials.

## Verification by affected behavior

```bash
python3 -I tools/check-desktop-icons.py
python3 -I tools/check-devtools.py
```

The icon check requires the normal Wayland/KDE session and installed guard. It checks configured controls, decoding, and helper labels without starting Claude or using an account. It does not replace visible-window or tray confirmation.

The developer check creates temporary Java/Cargo/Vite files under `~/src`, starts a local HTTP server and PTY, and checks inherited confinement, private-file denial, and Docker denial. It retrieves the existing GitHub token locally without printing it or making remote requests. It depends on the installed Java/Rust/pnpm tools, current GitHub login, and the local motion-atlas-workspace Vite installation. It is not a generic test suite and is unnecessary for documentation-only changes.

For GUI changes, check the affected actual controls, tray, or terminal. When relevant, Quit and confirm the main process and helpers end. Do not substitute backend registration or process survival for the interface behavior.

## Full rollback

Close clients first. Desktop depends on the CLI helper, so the order is Desktop, then CLI. Without `--apply`, the tools only inspect root-only backups and report intended changes:

```bash
sudo python3 -I tools/rollback-desktop.py
# Only when intentionally removing Desktop protection:
sudo python3 -I tools/rollback-desktop.py --apply
sudo python3 -I tools/rollback-cli.py
# Only when intentionally removing CLI protection:
sudo python3 -I tools/rollback-cli.py --apply
```

CLI rollback requires Desktop rollback first. The tools retain login, application data, caches, repositories, and backups; restore the current valid native CLI selection/package ELF; and remove only this deployment's integration. Desktop rollback removes module persistence and the added qiu ACL without forcibly unloading an in-use module.

Original backups are `20261005-223650`, `desktop-20261005-235542`, and `finish-20261006-114104` under `/var/backups/claude-guard/`. Later `repair-*`, `native-*`, `view-*`, `state-*`, `autostart-state-*`, and `devtools-*` backups remain there. Retain them locally. Default Desktop rollback inspection passed; actual protection removal was not performed.
