[Studraw](Index.md) / Optimisations

# Optimisations

Pending improvements only, highest priority first. Tags: `OPT` performance, `FAC`
factorisation, `EXT` extension, `SIM` simplification.

## P1

### FAC — shared UI building helpers

Every controller repeats the same `StyleBoxFlat` construction, button restyling and status-line
colouring from `Palette`. Extract a small library (a `components/ui` script or a static helper)
covering: flat panel, flat button with hover and pressed states, list and field styling, status
label colouring. Controllers keep their layout and wording; only the styling calls move. This
removes the drift risk where one screen gets a colour or margin the others do not.

### FAC — split the dev console controller

`dev_console_controller.gd` owns cheats, sync configuration, publication with its journal, the
raw file launcher, Wi-Fi forcing and profile deletion. Split it into one controller per section
(or one reusable section scene per concern) so each remains readable and testable. Keep the
window and its layout in the parent.

### SIM — shared JSON persistence helper

`MailManager`, `CommissionManager`, `AuthManager`, `SyncManager` and `CommissionEditor` each
repeat open / parse / validate / write. A small persistence helper would centralise atomic
writes and “unreadable file is never overwritten” handling. Behaviour must stay identical,
including the existing preservation of keys owned by another manager.

## P2

### OPT — avoid redundant cache reads

`apply_payload()` reloads and re-parses the cache on every payload, even when the caller already
holds it, and the merge loops over the whole payload each sync. Pass the cached document down
from the sync attempt and skip the merge entirely when the version is unchanged. Small win, but
it also makes the version rules single-sourced.

### FAC — login and Profil form plumbing

The login screen and the Profil app duplicate password fields, confirmation checks and status
messages. Factor the field validation and the message colouring into the shared UI helpers, then
keep each screen's step machine explicit.

### OPT — deadline scan granularity

`CommissionManager.check_deadlines()` scans every commission on each minute tick. With a handful
of commissions this is free; if the save grows, store an index of active deadlines and scan only
the earliest. Do not implement before real data justifies it.

### SIM — window content wrapping heuristic

`WindowComponent` walks the content tree to wrap labels and to derive a minimum size. This is
effective but implicit. Replace it with an explicit per-scene contract (a wrapping flag or a
dedicated container) once a third or fourth app joins, so window content behaviour is predictable
from the scene alone.

## P3

### FAC — test fixture extraction

`tests/test_scene.gd` holds helpers, fake managers and every test in one file. Extract the fake
auth and temporary-repository helpers when a second test scene appears, not before.

### EXT — publication streaming

Publication uses a blocking `OS.execute` on purpose: it is an administrator-only action and the
push is short. If pushes ever take long enough to freeze the notification queue, move the git
calls to a worker thread and report lines through the journal as they arrive.

### OPT — raw file viewer

The raw viewer reads the whole source into a label. If the source grows past a few hundred
kilobytes, switch to a virtualised or paged view.
