# Changes

## Memories

- Tests are consolidated: one test per durable system and one per inter-system interaction, never
  several tests per system or per interaction. New behaviour extends the existing test instead of
  adding a sibling.
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

## 2026-10-20 — M5 commission sync

Added `managers/sync_manager.gd` (autoload `SyncManager`, after `CommissionManager`): reads the
shared commissions from a local file or an HTTPS raw URL, caches the last valid payload in
`user://commissions_cache.json`, falls back to that cache when the source is missing, invalid or
unreachable, and repeats the fetch every `sync_interval_minutes`. The source is configured in
`user://sync_config.json` (`mode` local/remote, `local_path`, `remote_url`,
`sync_interval_minutes`); defaults are local mode on `res://data/commissions.json` with a 30 min
interval, so the app works before the public repo exists. Fetches never overlap.

Merge is by commission id. `CommissionManager` gained `create_offer()` (unknown id → one
`commission_offer` mail, id `offre_<commission id>`, unread, unarchived), `refresh_offer()` (same
id, still pending → subject, body, sender and definition updated in place, read state preserved)
and a persisted `seen_commissions` list. A payload whose `version` is lower than the cache is
ignored; a higher one enables the pending-offer refresh. Accepted, refused and archived
commissions are never recreated, refreshed or removed. Duplicate ids inside one payload produce a
single offer.

Commissions gained `client` and `sender`; `sender` may differ from the client when the latter is
a company. Mails renamed their `from` field to `sender` (old saves still load through a fallback)
and `MailManager.update_mail()` merges changes into a mail without resetting read / archived.
The mail reader shows the sender plus the client, the commissions list shows the client.
`ensure_demo_offer()` was removed; the desktop syncs at startup instead and shows a notification
for new offers only.

The dev console sync section gained a "Forcer Wi-Fi distant OK" checkbox that sets an in-memory
`SyncManager.force_remote_ok` flag and refreshes the taskbar indicator, so the distant/remote state
can be forced even when the source is unreachable.

Files touched: `data/commissions.json` (new), `managers/sync_manager.gd` (new),
`managers/commission_manager.gd`, `managers/mail_manager.gd`,
`controllers/desktop/desktop_controller.gd`, `controllers/mail/mail_app_controller.gd`,
`controllers/commissions/commissions_app_controller.gd`,
`controllers/dev/dev_console_controller.gd`, `controllers/dev/dev_console_controller.tscn`,
`project.godot`, `ROADMAP.md`, `tests/test_scene.gd`, `changes.md`.

Tests: added `T-SYNC` (system: validation, version guard, cache, config round-trip, interval and
cache fallback), `T-SYNC-COM` (sync + commissions: dedup, seen persistence, pending refresh,
accepted / refused untouched), `T-SYNC-MAIL` (sync + mails: offer mail shape, sender / client,
accept / refuse buttons, archived offers not refreshed) and `T-CHEAT-SYNC` (cheat + sync: config
round-trip through the console, manual sync status and resulting offer). 10 tests, 0 failure.

Manual check: launching the game in local mode turns the two `data/commissions.json` entries into
two offer mails with a single notification; a second launch creates no duplicate.

Why: M5 makes the shared commission feed reach the player without duplicating offers, and gives
the dev console the controls needed to exercise it before the public repo and M7 push exist.

Out of scope (deliberate): git push (M7), commission editor (M6), auth (M6), removing a
commission that disappeared from the feed, type / duration tables served by the JSON, cache
purge, updating already accepted or archived commissions.

Invalidated docs pages: none.

## 2026-10-20 — Sync status, local file viewer and Wi-Fi indicator

The dev console content now scrolls inside its window (`ScrollContainer` between the panel and the
box), so the sync section stays reachable on the 560x380 window.

The sync section gained a "Fichier local" button that opens a `Fichier local` window showing the raw
text of the configured local commission file (`controllers/dev/raw_file_controller.gd` / `.tscn`,
read-only, with a refresh button and the resolved path), plus a "Dernière sync" line reporting the
last attempt as `YYYY-MM-DD HH:MM:SS — succès|échec` in local time. The console now listens to
`sync_finished` for its whole lifetime, so a background or Wi-Fi triggered sync also refreshes that
line; `mode_changed` keeps the mode selector in step when the mode is changed elsewhere.

`SyncManager` gained `mode_changed`, `last_sync_at`, `last_sync_ok`, `last_sync_mode`, `set_mode()`
(validated, emits only on change) and `get_last_sync_text()`. A remote fetch with an empty URL now
counts as a failed sync instead of silently falling back to the local file, and `sync_finished`'s
`reachable` now reports the *source*, not the data: a cache fallback still applies the cache but
reports the source as unreachable, so a broken local path or remote URL is visible instead of being
hidden by the cache.

The taskbar shows a Wi-Fi indicator at the bottom right, before the clock
(`components/wifi/wifi_indicator.gd` / `.tscn`), with exactly three states: local (barred Wi-Fi,
grey), distant (Wi-Fi, green) and error (Wi-Fi with an alert, red). The error state replaces the
mode when the last sync of the *current* mode failed, so switching mode immediately clears a stale
error; a failed sync also raises a "Synchronisation impossible" notification, once per error
transition. Clicking the icon toggles local ↔ distant, saves the config and fetches immediately; the
dev console config does the same through `set_mode()`. The three icons are Material Design Icons
(Apache 2.0, `components/wifi/icons/`, notice included), parsed at runtime with
`Image.load_svg_from_string` and tinted with the new `Palette.WIFI_REMOTE` / `WIFI_LOCAL` /
`WIFI_ERROR` colours.

Files touched: `components/wifi/wifi_indicator.gd` (new), `components/wifi/wifi_indicator.tscn`
(new), `components/wifi/icons/` (new), `controllers/dev/raw_file_controller.gd` (new),
`controllers/dev/raw_file_controller.tscn` (new), `controllers/dev/dev_console_controller.gd`,
`controllers/dev/dev_console_controller.tscn`, `controllers/desktop/desktop_controller.gd`,
`controllers/desktop/desktop_controller.tscn`, `managers/sync_manager.gd`, `managers/palette.gd`,
`tests/test_scene.gd`, `changes.md`.

Tests: added `T-WIFI` (Wi-Fi + sync: local is the local state, a stale error clears when the mode
changes, a click switches to distant and saves the config, distant without URL is an error with a
notification, success is distant, failure is an error, back to local succeeds) and extended
`T-CHEAT-SYNC` (last sync label reports success, the raw file window opens with the local JSON
text) and `T-SYNC` (a cache fallback keeps the cache but reports the source unreachable).
11 tests, 0 failure.

Manual check: the dev console scrolls to the sync section, "Fichier local" shows
`res://data/commissions.json`, clicking the Wi-Fi icon turns it red with a "Synchronisation
impossible" notification when no URL is set, and grey once back in local mode.

Why: the sync had no visible state, and the dev console had no way to inspect the feed it reads.

Out of scope (deliberate): exporting the raw `.svg` sources as non-resource files for a future
export build, editing the local file from the viewer, retry policy, persisting `last_sync_at`
across launches.

Invalidated docs pages: none.

## 2026-10-20 — Mail notification badges and commission delivery in the roadmap

`ROADMAP.md` gained two future milestones, not implemented: `M8` (notify on every new mail, unread
badge on the Courrier app button, toast notifications coloured by type) and `M9` (click a commission
to deliver it with an attached image, success before the deadline and failure after it, plus a
galerie app listing the delivered images).

Files touched: `ROADMAP.md`, `changes.md`.

Invalidated docs pages: none.

## 2026-10-21 — M6a (1/2) local profiles and per-profile saves

Added `managers/auth_manager.gd` (autoload `AuthManager`): local profiles persisted in
`user://profiles.json`, SHA-256 passwords, creation, connection, logout, pseudo / password change,
deletion with the profile password or with the admin password from the dev console, and the
`session_changed` / `profiles_changed` signals. A single `admin` / `admin` profile is seeded
(`is_admin: true`); every created profile is non-admin, no promotion exists, and deleting the only
admin profile is refused by both deletion paths. A password hash never leaves the manager.

Player state is now per profile: `user://profiles/<id>/save.json`, with the profile directory created
when the profile is loaded or created. The legacy `user://save.json` is copied once into the admin
save when the latter is absent, leaving the original untouched, so existing state survives. The sync
source and its cache stay machine-wide.

M6 was split into `M6a` (profiles, session, editor gate) and `M6b` (commission editor): planning added
a multi-profile Profil app, a login screen and per-profile saves, beyond the original constant-hash
dev account. `M6a` is deliberately two commits — this one holds the auth data layer and the state
split, the next one the screens.

Tests: `T-AUTH` (`AuthManager`: seed, login, creation validations, credential change and persistence,
deletion by profile and by admin password, last-admin guard, session signals, unreadable profile file
left untouched) and `T-AUTH-SAVE` (auth + player state: no save sharing between profiles, one-shot
legacy migration that does not duplicate on reload). 13 tests, 0 failure.

Files touched: `managers/auth_manager.gd` (new), `project.godot`, `ROADMAP.md`, `tests/test_scene.gd`,
`changes.md`.

Why: the player state must stop being shared before profiles become a login gate, and the auth layer
has to be testable without any screen.

Out of scope (deliberate): login screen, Profil app, desktop gate and admin deletion UI (M6a second
commit); commission editor (M6b); password recovery or reset, profile promotion, session persistence
across launches, password salting, orphan save purge.

Invalidated docs pages: none.

## 2026-10-21 — M6a (2/2) login screen, profile app and admin gate

The app now starts on `controllers/login/login_controller.gd` + `.tscn` (new main scene) in labelled
steps: "Étape 1 sur 2 — Choisissez un compte" lists the profiles with "Continuer" and "Nouveau profil"
(pseudo, password, confirmation, "Retour"), then "Étape 2 sur 2 — Mot de passe" shows the selected
pseudo, the password field, "Se connecter" and "Retour". The admin profile is filtered out of the list;
five left clicks on the "Studraw" title reveal it, select it and open its credentials step directly.
A successful connection wires
`MailManager.save_path` and `CommissionManager.save_path` to the profile save through
`AuthManager.get_profile_save_path()` and reloads both, then switches to the desktop. The switch only
happens when the login screen is the current scene, so tests can drive it without replacing their own
scene.

Added `controllers/profile/profile_controller.gd` + `.tscn` ("Profil" button, always visible) as a
step machine: the first step only offers actions ("Changer mes identifiants", "Supprimer le profil",
"Se déconnecter"); the change flow asks for the new pseudo / password / confirmation, then a separate
step for the current password; the delete flow asks for the password in its own step. No password field
is visible before the matching action is chosen. A saved change returns to the actions, a deletion
removes the profile and its save and leads back to the login screen. The admin profile cannot be
deleted this way.

The taskbar gained a "Déconnexion" button: it closes the session and returns to the login screen
without opening the Profil app.

The desktop hides "Console dev" unless `AuthManager.is_dev_session()` is true and reacts to
`session_changed`. The dev console gained a "Profils" section (profile list, admin password field,
delete button) using `delete_profile_as_admin()`, hidden outside an admin session.

Palette gained `DANGER_BACKGROUND`, `DANGER_BACKGROUND_HOVER`, `DANGER_BACKGROUND_PRESSED`,
`DANGER_TEXT`, `STATUS_TEXT`, `STATUS_ERROR_TEXT` and a `status_color(kind)`
resolver; the login, profile and console screens build every style from them, no literal colour. Status
lines are white (`STATUS_TEXT`) and only turn red for errors and warnings — no green outside the Wi-Fi
state.

Tests: added `T-AUTH-DSK` (auth + screens: the admin is hidden from the selection, four clicks on the
title keep it hidden and the fifth reveals it and opens its credentials step, creation replaces the
selection and leads to the credentials step, the back button returns to the selection, mismatched confirmation
refused, failed login leaves the save unwired, successful login wires both managers and emits one
signal, desktop gate hidden for a standard profile and shown for the admin, profile app starts on its action buttons, the change action opens the credentials step then a separate
current-password step, a saved change returns to the actions, the delete action opens its own
confirmation step, deletion refused with a wrong password and applied with the right one — save
removed and login requested — admin profile not deletable from the app, taskbar logout closing the
session, console deletion refused with a wrong admin password and applied with the right one). 14
tests, 0 failure. T-CHEAT-SYNC needs no change: the console gate lives in the desktop, and profile
deletion is guarded in `AuthManager`, both already covered.

Files touched: `controllers/login/login_controller.gd` (new), `controllers/login/login_controller.tscn`
(new), `controllers/profile/profile_controller.gd` (new), `controllers/profile/profile_controller.tscn`
(new), `controllers/desktop/desktop_controller.gd`, `controllers/desktop/desktop_controller.tscn`,
`controllers/dev/dev_console_controller.gd`, `controllers/dev/dev_console_controller.tscn`,
`managers/palette.gd`, `project.godot`, `tests/test_scene.gd`, `changes.md`.

Why: profiles have to be selected before any player state exists, and the dev tools must not exist
for a standard profile.

Out of scope (deliberate): commission editor (M6b), session persistence across launches, password
recovery, deleting a profile while its save is in use by another screen, per-profile window layout.

Invalidated docs pages: none.
