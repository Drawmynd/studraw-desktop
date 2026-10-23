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
- Planned (ROADMAP M15): make the palette editable from the editor with a custom `Resource`
  (`class_name PaletteData` with `@export` colours) saved as `res://theme/palette.tres`, loaded by
  the `Palette` autoload as a facade (`Palette.colors`). An `enum` + `@export` cannot edit values
  and a full addon is unnecessary; per-node injection is deferred until runtime themes exist. A
  bare autoload script cannot expose `@export` colours.
- Headless tests: the `godot` CLI on this machine is 4.4.1, which cannot parse the MCP addon
  (`MCPGameBridge` fails on the missing `Logger` base class). To run `tests/test_scene.tscn`,
  temporarily comment out the `MCPGameBridge` autoload, run with `godot_console.exe` (the
  `godot.exe` shim returns without output), then restore `project.godot`.
- The source editor works on a staging copy (`user://pending_commissions.json`); the published
  source (`SyncManager.local_path`) is only written by `CommissionEditor.push()`. Commissions stay
  denormalised (`client`, `sender`, `type`, effective `duration`) next to their `client_id` /
  `type_id`, so receivers never need the `clients` / `types` lists. A deletion only affects new
  receivers: the merge never removes an already-received commission.
- Git publishing commits only `local_path` (resolved relative to `repo_path`) and never pulls. The
  repository, the source location inside it and the remote are validated before any `git add`, so a
  missing remote leaves the repository untouched. `OS.execute` stays blocking on purpose: it is an
  admin-only dev action, and a worker thread would buy little for a one-shot push.
- Deliveries live under the profile save folder: `CommissionManager.save_path.get_base_dir()/deliveries/<commission_id>/`,
  derived without `AuthManager`, so tests stay isolated and profile switching needs no extra wiring.
  Validation uses the extension, the magic bytes and a decode; the cap is 10 Mo. A commission holds
  one delivery, only after a successful `complete()`.
- `CommissionManager.complete(commission_id, delivery, now)` is the on-time deadline gate and
  `record_delivery()` the finished-commission path: a delivery after the deadline is accepted on a
  failed commission and flagged `delivery_late`. The gallery reads any commission carrying a
  `delivery_path`; a missing file is listed but reported as introuvable.

## 2026-10-23 — M9 image delivery and gallery

Added image delivery from a commission. `DeliveryManager` (autoload) validates PNG, JPG and WebP by
extension, magic bytes and decode, caps a file at 10 Mo, copies the original bytes under
`user://profiles/<id>/deliveries/<commission_id>/` and rolls the copy back when the commission
refuses it. `CommissionManager.complete()` takes an optional delivery and an explicit time, stores
`delivery_path`, `delivery_name`, `delivered_at` and `delivery_late`, and refuses an on-time
completion once the deadline has passed. `record_delivery()` accepts an image on a finished
commission without changing its status or sending a mail. The Commissions app carries a « Livrer »
button on active and finished rows; finished rows report their outcome, including « Livré trop tard
le … ». The delivery window previews the picked image letterboxed, allows replacing or clearing it,
and closes with a notification after sending. The Galerie app lists every commission carrying a
delivery in a thumbnail grid or a list, with an integrated viewer showing client, type and date, a
late marker, the delivered image exactly, or « Image introuvable » when the file is gone.

Files: `managers/delivery_manager.gd`, `managers/commission_manager.gd`,
`controllers/delivery/`, `controllers/gallery/`, `controllers/commissions/`,
`controllers/desktop/`, `components/window/window_component.gd`, `project.godot`,
`tests/test_scene.gd`, `ROADMAP.md`.

Out of scope: cropping, editing, format conversion, several images per commission, video, cloud
storage, deletion of a delivery, gallery search/filters/EXIF, thumbnail cache, backup of deliveries.
`FileDialog` itself is not tested; the path is injected.
Docs invalidated: `docs/data/PlayerSave.md`, `docs/api/CommissionManager.md`, `docs/api/Index.md`,
`docs/Features.md`, `docs/Architecture.md`.

## 2026-10-21 — Roadmap reevaluation

Replaced the milestone history with a compact shipped base and a forward-looking phase list.
Removed the completion marker, merged the window-snapping and application-resizing items into
M10, merged notifications, badge and inbox actions into M8, folded the duplicated prerequisites
into a working-machine note, replaced the duplicated data models with links to `docs/data/`, and
reduced the stale proposed-test list to the quality bar already enforced by `tests/test_scene.gd`.

Added phases: M11 progress and statistics, M12 content variety and client history, M13
accessibility and input, M14 data safety and portability, M15 editable palette, M16 Windows
release. M9 now specifies image rendering (preview, viewer, formats, size cap, per-profile
storage). Their data needs (difficulty, follow-up, streak, backup, palette resource) are
deliberately not designed yet. Phase sections are priority-ordered: M9 first, then M15, then the
base order; identifiers stay stable.

Files: `ROADMAP.md`; milestone references updated in `docs/Features.md` and `docs/Changelog.md`;
the palette optimisation entry removed from `docs/Optimisations.md` because it is now a phase.
Docs invalidated: `docs/api/Palette.md` and the palette convention in `docs/Architecture.md` once
M15 lands.

