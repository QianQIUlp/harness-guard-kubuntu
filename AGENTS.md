# Maintenance instructions

## Read before changing the deployment

Start with `README.md`, `docs/ARCHITECTURE.md`, and the relevant part of `docs/OPERATIONS.md`. Use `docs/VALIDATION.md` to distinguish verified behavior from incomplete coverage. The deployment snapshot is timestamped evidence, not a live process inventory.

Maintain the existing CLI/Desktop deployment. Do not rebuild an older policy draft or treat superseded failures as current defects. Native CLI updates, desktop controls, tray, startup toggle, and the conversation terminal have already been restored.

## Working approach

- Consult the designated Context7 connector before deciding changes to AppArmor, GLib/GTK, Glycin, Electron, or development-tool mechanisms: resolve the relevant library, then query the specific issue. Reuse applicable prior results. Match documentation to local versions; fill gaps with official versioned source and actual local behavior.
- Identify the failing layer, its direct dependencies, affected functionality, and the smallest meaningful check before editing. Configuration, image decoding, desktop IPC, PTY setup, and file mediation are distinct layers.
- Reuse existing code, native tools, and standard libraries. Do not introduce speculative abstractions, new deployment frameworks, permanent check infrastructure, or additional permission gates.
- Account for functional compatibility, security boundaries, maintenance cost, execution time, and user attention together. A single rule passing or a process remaining alive is insufficient evidence for a complete user workflow.
- Runtime trust resides in root-owned installed copies, not this writable repository. Repository maintenance does not imply authorization to change unrelated machine settings or projects.
- Validate the changed scope. Reuse unchanged passing evidence; do not repeat model requests, sign-ins, historical executable probes, or application launches for documentation purposes.
- Answer status questions directly. Stop when the requested outcome and necessary checks are complete.

## Established permission decisions

- All of `/home/qiu/src/**` is authorized. Shared `.agents/skills` are read-only and may execute with inherited confinement. Additional workspaces require authorization for the actual paths and the changes described in Operations.
- Installed development tools and GitHub credentials are permitted. Go/Ruby installation was not requested. The root Docker/Containerd service sockets remain denied.
- Desktop uses the existing encrypted KWallet login path. Shared `readPassword` access is an accepted exception; wallet writes and a custom plaintext login fallback are not authorized.
- The vendor MCP sensitive-configuration exception path is left unchanged. Its presence is not evidence that the current deployment triggered it.
- Cowork's persistent `vhost_vsock` module setup and UID 1000 device ACL have been explicitly authorized and installed. Device access does not prove a full Cowork VM task works.
- The private migration environment script remains unreadable because it contains unrelated service credentials. A shell startup warning does not justify opening those credentials.
- Preserve network routing, global KDE settings, unrelated policies, application data, and root backups. Do not remove enforcement to investigate a GUI issue.

## Records and publication

Record material changes, checks, timestamps, and limits in the relevant engineering documents. Do not copy conversational wording or personal concerns into project documentation. Historical PIDs and hashes apply only to their recorded state.

Review the files actually being committed. Do not publish tokens, wallet values, private application configuration, raw account/session logs, core dumps, backups, or unrelated code. Context7 queries must not contain local secrets or private source.

Full protection removal is an explicit rollback operation: close clients, then roll back Desktop before CLI because Desktop depends on the CLI helper. Existing verification tools are sufficient unless a changed behavior creates a concrete coverage gap.
