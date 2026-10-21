[Studraw](../Index.md) / API

# API index

Manager modules hold all player state and business rules; screens only call them and style
their scene.

| Module | Responsibility |
| --- | --- |
| [ClockManager](ClockManager.md) | real clock, second and minute ticks |
| [Palette](Palette.md) | single source of every colour |
| [AuthManager](AuthManager.md) | profiles, passwords, session, per-profile saves |
| [MailManager](MailManager.md) | inbox, read state, archive, persistence |
| [CommissionManager](CommissionManager.md) | commission lifecycle, deadlines, offer merge |
| [SyncManager](SyncManager.md) | source fetch, cache, configuration, git publication |
| [CommissionEditor](CommissionEditor.md) | source document, staging draft, validation, local publish |
| [Desktop shell](DesktopShell.md) | desktop controller, window component, taskbar, Wi-Fi indicator |
| [Applications](Applications.md) | login, Courrier, Commandes, Éditeur, Console dev, Profil, raw file |

## Module order

Autoloads are registered in this order: ClockManager, Palette, AuthManager, MailManager,
CommissionManager, SyncManager, CommissionEditor. Dependencies are resolved lazily from `/root`,
so a module started alone (as in tests) works as long as it is given its collaborators.

## Rules

- A manager never reaches into a controller.
- A controller never writes a data file directly; it calls a manager.
- Managers preserve keys they do not own when rewriting the shared player save.
- Every state change that matters emits a signal, so screens refresh without polling.
