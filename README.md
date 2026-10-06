# harness-guard-kubuntu

Maintenance repository for the existing Claude Code CLI and Claude Desktop AppArmor deployment on `tele`, user `qiu` (UID 1000), running Kubuntu with KDE/Wayland.

The deployment preserves native development tools, desktop integration, and vendor updates while restricting private host files and privileged host services. Runtime enforcement uses root-owned installed files. Editing this repository does not change the running system.

## Start here

| Document | Purpose |
| --- | --- |
| [AGENTS.md](AGENTS.md) | Instructions for the next maintenance agent |
| [Architecture](docs/ARCHITECTURE.md) | Entry points, dependencies, permissions, and accepted exceptions |
| [Operations](docs/OPERATIONS.md) | Updates, permission changes, deployment, checks, and rollback |
| [Validation](docs/VALIDATION.md) | Verified behavior and remaining limits |
| [Technical history](docs/HISTORY.md) | Relevant failures, causes, fixes, and superseded states |
| [Deployment snapshot](evidence/deployment-2026-10-06.json) | Timestamped versions, hashes, labels, and device permissions |

The current CLI supports official updates and version activation. Java, Rust/Cargo, pnpm/Vite, and the conversation terminal work under both guards. Desktop window controls, tray, and startup toggle have been confirmed in the actual interface. The root Docker service remains isolated. Go and Ruby were not installed.

## Contents

```text
files/       Deployed source files, profiles, shared rules, and GTK schema sources
tools/       Existing verification and rollback tools
docs/        Engineering documentation
evidence/    Deployment and repository packaging records
LICENSES/    Licenses for reused upstream files
```

The repository name is `harness-guard-kubuntu`. Existing `claude-*` runtime paths and policy labels are retained for deployment compatibility. The filename `claude-code-guard-v4.profile` is historical; its contents are the final deployed policy, not an initial v4 draft.

## Initial checks

Run from the repository root on the existing host:

```bash
python3 -I files/claude-code-launch.py --guard-self-check
python3 -I files/claude-desktop-launch.py --guard-self-check
```

These existing self-checks do not start Claude or invoke an account. Policy validation and maintenance steps are documented in [Operations](docs/OPERATIONS.md). No new installer, updater, or policy management framework is included.

This is a host-specific maintenance archive, not a fresh-machine installer. It depends on `/home/qiu`, UID 1000, NVM v22.23.2, KDE/Wayland, the existing LOCAL executable diversion, and local rollback backups. Adapt those dependencies before using it on another machine.

To maintain the repository using a guarded Claude session, clone it into `~/src/harness-guard-kubuntu`; the entire `~/src` tree is already authorized.

Root backups remain in `/var/backups/claude-guard/`. Credentials, application data, raw conversation logs, core dumps, vendor application bundles, and unrelated project code are excluded. Upstream attribution is in [THIRD_PARTY.md](THIRD_PARTY.md).
