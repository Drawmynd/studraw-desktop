# Changes

## Memories

- Studraw is a drawing-motivation app (fake artist studio desktop), not a drawing tool.
  The player draws elsewhere; the app only motivates. Recording this so a later session
  does not propose adding a canvas.
- `docs/` is not written unless asked. Working log is `changes.md`; phases live in
  `ROADMAP.md` at the project root.
- Every colour lives in `managers/palette.gd` (autoload `Palette`) under a name, written as a
  hex string (`Color("#212e3d")`, 8 digits when alpha matters). No inline colour anywhere else,
  neither in `.gd` nor in `.tscn`: components and scenes build their `StyleBox` from the palette.
  Add a new named hex entry instead of a literal.
- MCP `godot` recovery does not need an OpenCode restart: `opencode api post
  "/api/experimental/mcp/godot/disconnect?location[directory]=<project>"` then the same with
  `connect`. The addon accepts one client only, so disconnect other directories first
  (`C:\Users\Admin`); OpenCode marks the server failed after one timed-out handshake and never
  retries on its own.
- To plan (Optimisations, `EXT`): make the palette editable from the editor. Requires a custom
  `Resource` (`class_name PaletteData` with `@export` colours) saved as `res://theme/palette.tres`,
  injected via `@export var palette: PaletteData` on controllers/components, with the autoload
  either loading it or disappearing. A bare autoload script cannot expose `@export` colours; no
  plugin is needed. Deferred for now.
- Headless tests: the `godot` CLI on this machine is 4.4.1, which cannot parse the MCP addon
  (`MCPGameBridge` fails on the missing `Logger` base class). To run `tests/test_scene.tscn`,
  temporarily comment out the `MCPGameBridge` autoload, run with `godot_console.exe` (the
  `godot.exe` shim returns without output), then restore `project.godot`.

## 2026-10-18 — Initial roadmap and scope

Added `ROADMAP.md` capturing the agreed scope, fixed decisions, data models and
milestones M1–M7. Files touched: `ROADMAP.md`, `changes.md` (created).

Why: the plan discussed in conversation needed a durable home for the phases.

Out of scope (deliberate): drawing canvas, multiplayer / online accounts / backend,
web deployment. Also deferred: repo URL and `git init` are user-side prerequisites.

Invalidated docs pages: none (no `docs/` yet).

## 2026-10-18 — M1 Project setup

Switched `project.godot` to the Desktop feature tag (renderer stays Mobile),
1280x720 viewport, registered the `ClockManager` autoload, and set the main scene
to `controllers/desktop/desktop_controller.tscn`. Added `managers/clock_manager.gd`
(real-time clock, one-second tick) and the paired
`controllers/desktop/desktop_controller.gd` + `.tscn` (fake desktop background,
bottom taskbar with a live clock). Removed the unused engine placeholder
`node_2d.gd` + `node_2d.gd.uid`.

Files touched: `project.godot`, `managers/clock_manager.gd`,
`controllers/desktop/desktop_controller.gd`,
`controllers/desktop/desktop_controller.tscn`, `changes.md`; deleted `node_2d.gd`,
`node_2d.gd.uid`.

Why: M1 establishes the folder tree, the singleton manager layer and a runnable
desktop with a live clock, so later milestones can build on it.

Out of scope (deliberate): window system / `WindowComponent` (M2); other managers
(Auth, Mail, Commission, Sync — M3–M6); `components/` tree, whose first real
component lands in M2.

Invalidated docs pages: none.

## 2026-10-19 — M2 Window system

Added `managers/palette.gd` (autoload `Palette`): the single source of every colour, each under
a name and written in hex (`DESKTOP_BACKGROUND`, `TASKBAR_BACKGROUND`, `WINDOW_BACKGROUND`,
`WINDOW_BORDER`, `TITLE_BACKGROUND_ACTIVE/INACTIVE`, `TITLE_TEXT_ACTIVE/INACTIVE`,
`APP_BUTTON_*`). No inline colour remains in any `.gd` or `.tscn`; the desktop, taskbar,
window panel, title bar and app buttons build their `StyleBox` from the palette.

Added `components/window/window_component.gd` + `.tscn`: reusable window with drag by the
title bar, edge and corner resize (minimum size, clamped to the work area above the taskbar),
maximize / restore (title-bar button and double-click), minimize, close, and active /
inactive title-bar styling. The taskbar height and cascade offset are `@export` tunables.
Mouse handling reads event coordinates rather than the OS cursor, so it behaves identically
under injected input.

`desktop_controller.gd` / `.tscn`: a `Windows` layer between the background and the taskbar,
the taskbar split into a window-button list and the clock, `open_window(title, content)` with
cascade placement, focus of the topmost window under a click, and minimize / restore through
the taskbar button. Two desktop buttons ("Courrier", "Console dev") open placeholder windows
until the real apps land in M3 / M6; no window opens at startup.

Files touched: `managers/palette.gd`, `project.godot` (Palette autoload),
`components/window/window_component.gd`, `components/window/window_component.tscn`,
`controllers/desktop/desktop_controller.gd`, `controllers/desktop/desktop_controller.tscn`,
`changes.md`.

Why: M2 gives every later app a place to live and closes the window lifecycle end to end;
the palette keeps colour decisions in one named place before the app shells multiply.

Out of scope (deliberate): desktop icons and real app content (M3); persistence of window
position / size; snapping; native engine windows.

Invalidated docs pages: none.

## 2026-10-20 — One test per durable system

Added `tests/test_scene.gd` + `tests/test_scene.tscn`: a single scene-run suite, no external
framework. One test per system that survives the coming milestones:

- `T-CLK` (`ClockManager`): 3.5 s of deltas emits exactly 3 ticks; `get_time_string()` keeps
  the `HH:MM:SS` shape. Uses a fresh instance, so the real-time autoload does not interfere.
- `T-WIN` (`WindowComponent`): drag by the title bar, resize by the bottom-right corner,
  maximize / restore (exact rect round-trip), minimum size, minimize / restore, and a close
  button that emits `closed` once and frees the node; every rect is checked against the work
  area so the taskbar stays uncovered.
- `T-DSK` (`DesktopController`): two windows via `open_window`, cascade / topmost order, click
  on the back window then on the overlap, taskbar button dimming and restore, and closing the
  focused window without leaving a dead button or an unusable remaining window.
- `T-PAL` (`Palette`): static scan of every `.gd` / `.tscn` outside `managers/palette.gd`,
  `tests/` and `addons/`, asserting zero literal `Color(`.

All four pass: 4 tests, 0 failure, exit code 0.

Run: `godot --headless --path . res://tests/test_scene.tscn`

Files touched: `tests/test_scene.gd`, `tests/test_scene.tscn`, `changes.md`.

Why: the window state machine and the window / taskbar signal contract are the parts that
already broke during M2; one guard per durable system keeps the cost low without testing the
temporary app buttons and placeholder content.

Out of scope (deliberate): test framework, CI wiring, tests for the app buttons and
placeholder windows (M3 / M6 replace them), visual rendering. The duplicated 40 px taskbar
height (`offset_top = -40` in the scene, `taskbar_height = 40` in the component) is left
untouched: it should be removed in code, not pinned by a test.

Invalidated docs pages: none.

## 2026-10-20 — Godot MCP addon enabled

Installed `@satelliteoflove/godot-mcp` 4.1.11 into `addons/godot_mcp` and enabled it in
`project.godot` under `[editor_plugins]`. Restarted the editor, which now listens on
`127.0.0.1:6550`.

Files touched: `project.godot`, `addons/godot_mcp/**` (third-party), `changes.md`.

Why: the MCP server had lost its editor-side plugin, so the assistant tools could not attach.

Out of scope (deliberate): updating the MCP package, bind / port settings, exposing the addon
to other projects.

Reconnecting without restarting OpenCode: the server marks `godot` failed after one timed-out
handshake and does not retry. Use the runtime endpoint instead, with the project as `location`:
`POST /api/experimental/mcp/godot/disconnect?location[directory]=<project>` then
`.../connect?location[directory]=<project>` (through `opencode api`). The addon accepts a single
client, so disconnect any other directory first (e.g. `C:\Users\Admin`), otherwise the project
Invalidated docs pages: none.

## 2026-10-20 - M3 boîte mail et archives

Added `managers/mail_manager.gd` (autoload `MailManager`): inbox list, read / unread state,
archiving, and persistence in `user://save.json` under the `mails` key while preserving any
other keys. A welcome mail is seeded the first time the mail app opens, and not re-seeded
afterwards.

Added `controllers/mail/mail_app_controller.gd` + `.tscn`: message list, reading pane,
mark-as-read on selection, a red "Supprimer" button that moves the selected message to the
archive, and a toggle that reads "Archives" in the inbox and "Boîte de réception" in the
archive view. The desktop "Courrier" button now opens this app instead of a placeholder.

Palette: added `MAIL_LIST_BACKGROUND`, `MAIL_READING_BACKGROUND`, `MAIL_SELECTED_BACKGROUND`,
`MAIL_HEADER_TEXT`, `MAIL_TEXT`, `MAIL_META_TEXT`, `MAIL_UNREAD_TEXT`,
`MAIL_DELETE_BACKGROUND`, `MAIL_DELETE_BACKGROUND_HOVER`,
`MAIL_DELETE_BACKGROUND_PRESSED` and `MAIL_DELETE_TEXT`.

Tests: added `T-MAIL` to `tests/test_scene.gd` covering the unique seed, the defensive copy
returned by `get_mails`, mark-as-read, read-state persistence, mail addition, archiving,
archive persistence and the `mails_changed` emission count. 5 tests, 0 failure.

Manual check: the desktop "Courrier" button opens the app; selecting the welcome mail marks
it read; "Supprimer" moves it to Archives, and the delete action is hidden in archive view.

Files touched: `managers/palette.gd`, `managers/mail_manager.gd`,
`controllers/mail/mail_app_controller.gd`, `controllers/mail/mail_app_controller.tscn`,
`controllers/desktop/desktop_controller.gd`, `project.godot`, `ROADMAP.md`,
`tests/test_scene.gd`, `changes.md`.

Why: M3 delivers the local mail loop the rest of the app depends on; archiving keeps the
inbox clean without destroying mail history.

Out of scope (deliberate): network sync (M5), commissions (M4), restoring from the archive,
permanent deletion, search, folders, attachments, and a desktop unread badge.

Invalidated docs pages: none.

## 2026-10-20 — M4 commission lifecycle

Added `managers/commission_manager.gd` (autoload `CommissionManager`): accept, refuse and
complete a commission, compute `deadline = accepted_at + duration_minutes * 60`, track
`active|success|failed`, and persist `commissions` plus `refused` in `user://save.json` while
preserving the `mails` key owned by `MailManager`. Reminder mails (H-24, H-1) and the failure
mail use deterministic ids and per-commission flags, so each is emitted once.

`ClockManager` now also emits `minute_tick` from a separate 60-second accumulator and exposes
`get_unix_time()`. `CommissionManager` checks deadlines on every minute tick; the desktop shows
a non-modal notification for reminders and failures in addition to the mail.

Mail objects gained optional `type` and `commission` fields. `MailAppController` renders
Accepter / Refuser buttons for `commission_offer` mails; accepting transfers the commission into
`CommissionManager` and the running countdown list, then archives the mail. The desktop gained a
"Commandes" button and `controllers/commissions/commissions_app_controller.gd` + `.tscn`, which
lists active commissions and refreshes their remaining time every second.

A single demo commission offer is seeded on a fresh install (desktop startup) so M4 is usable
before sync lands; it is replaced by real offers in M5.

Files touched: `managers/clock_manager.gd`, `managers/commission_manager.gd`,
`managers/mail_manager.gd`, `managers/palette.gd`, `controllers/mail/mail_app_controller.gd`,
`controllers/mail/mail_app_controller.tscn`,
`controllers/commissions/commissions_app_controller.gd`,
`controllers/commissions/commissions_app_controller.tscn`,
`controllers/desktop/desktop_controller.gd`, `controllers/desktop/desktop_controller.tscn`,
`project.godot`, `tests/test_scene.gd`, `changes.md`.

Tests: added `T-COM` covering the commissions list app, the mail-to-list transfer, acceptance and
deadline computation, and the H-24 / H-1 reminders driven by `ClockManager.minute_tick`, including
the no-duplicate guarantee. 6 tests, 0 failure.

Why: M4 turns the local mail loop into a timed commission lifecycle and makes the countdown,
acceptance and refusal visible to the player.

Out of scope (deliberate): network sync (M5), dev editor (M6), git publish (M7), restoring from
the archive, search, desktop unread badge.

Invalidated docs pages: none.

## 2026-10-20 — Commission duration by type

Commission definitions now follow `{id, title, type, duration, description, mail_request,
mail_success, mail_failure}`. `duration` is an optional override in minutes; when null,
`CommissionManager.TYPE_DURATIONS_MINUTES` resolves the duration from the commission type. Deadlines are
computed as `accepted_at + duration_minutes * 60`, and the persisted state keeps the resolved
`duration_minutes` alongside the original override.

The demo offer, the commissions list (type + resolved duration) and `T-COM` were updated. The
`ROADMAP.md` data model and M6 form fields follow the same shape. Success and failure mails now
use `mail_success` and `mail_failure`, with a generated fallback when empty; offer mails use
`mail_request` as their body.

Files touched: `managers/commission_manager.gd`,
`controllers/commissions/commissions_app_controller.gd`, `tests/test_scene.gd`, `ROADMAP.md`,
`changes.md`.

Why: commissions are now authored as reusable types with a per-commission duration override,
which keeps the shared data small and the mail copy in the commission itself.

Out of scope (deliberate): remote `type -> minutes` overrides (M5 sync), dev form (M6).

Invalidated docs pages: none.

## 2026-10-20 — English commission identifiers

Renamed the internal commission and state fields to English: `title`, `duration`,
`duration_minutes`, `status`, `mail_request`, `mail_success`, `mail_failure`, and
`TYPE_DURATIONS_MINUTES`. Removed the French-key fallbacks. Test failure messages were translated
to English as well.

UI labels, mail subjects / bodies and demo content remain French, which is the app's chosen UI
language. No data migration is provided for the short-lived French-key saves.

Files touched: `managers/commission_manager.gd`,
`controllers/commissions/commissions_app_controller.gd`, `tests/test_scene.gd`, `ROADMAP.md`,
`changes.md`.

Why: keep the codebase identifiers and developer-facing messages in English while preserving the
French product language.

Out of scope (deliberate): translating UI copy or shared commission content.

Invalidated docs pages: none.

## 2026-10-20 — Dev console cheat buttons

Replaced the "Console dev" placeholder with `controllers/dev/dev_console_controller.gd` + `.tscn`.
It offers a clean test-state reset, a new offer mail, and notification / mail cheats for the 24 h
reminder, 1 h reminder, failure and success. The reset clears mail and commission state, reseeds
the welcome mail and demo offer, then creates three active fixture commissions covering the
default and overridden duration paths.

Added `MailManager.clear_all()` and `CommissionManager.clear_all()`. `ensure_welcome_mail()` now
checks for the welcome mail id instead of the save file's existence, so a reset can reseed it.
The desktop also listens to `commission_completed` and shows a success notification.

Files touched: `managers/mail_manager.gd`, `managers/commission_manager.gd`,
`controllers/dev/dev_console_controller.gd`, `controllers/dev/dev_console_controller.tscn`,
`controllers/desktop/desktop_controller.gd`, `changes.md`.

Why: exercise notifications, mails and commission flows quickly without waiting for real
deadlines or hand-editing `user://save.json`.

Out of scope (deliberate): a persistent debug menu, time travel for the clock, automated UI tests
for the dev console.

Invalidated docs pages: none.
