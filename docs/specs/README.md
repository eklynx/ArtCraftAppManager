# ArtCraft Application Manager — Specifications

These documents are the source of truth for behaviour. Code and tests trace back to them.

| Doc | Area ID | Contents |
|---|---|---|
| [01-overview.md](01-overview.md) | `OVR` | Purpose, goals, non-goals, platform |
| [02-app-registry.md](02-app-registry.md) | `REG` | `apps.json`, release resolution, version comparison, rate limits |
| [03-install-update.md](03-install-update.md) | `INS` | Detect, install, update, uninstall, run, reveal |
| [04-main-window.md](04-main-window.md) | `WIN` | Main window rows, status line, menu bar item |
| [05-settings.md](05-settings.md) | `SET` | Settings window and persistence |
| [06-notifications.md](06-notifications.md) | `NOT` | Notifications, update-check schedule, auto-update matrix |
| [07-errors-and-status.md](07-errors-and-status.md) | `ERR` | Error catalogue and status-line text |
| [08-architecture.md](08-architecture.md) | `ARC` | Modules and the protocols between them |
| [09-test-plan.md](09-test-plan.md) | `TST` | Test strategy and REQ → test matrix |

Related: [`../registry/apps.json`](../registry/apps.json), [`../registry/apps.schema.json`](../registry/apps.schema.json), [`../../GLOSSARY.md`](../../GLOSSARY.md), [`../adr/`](../adr/), UI prototype [`../prototypes/ApplicationLine.svg`](../prototypes/ApplicationLine.svg).

## Conventions

- Requirement IDs are `REQ-<AREA>-<n>` (e.g. `REQ-INS-4`). IDs are never reused; a removed requirement is marked `(withdrawn)`.
- Keywords **MUST**, **SHOULD**, **MAY** follow RFC 2119.
- Every `REQ-*` ID must appear in the name or a comment of at least one test (enforced by `REQ-TST-1`).
- Terms in *italics* on first use are defined in the glossary.
- `TODO-verify` marks a fact that must be confirmed against a real artefact during implementation.
