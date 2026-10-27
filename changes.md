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
- Every colour lives in `theme/palette.tres` (a `PaletteData` resource) with its defaults in
  `theme/palette_data.gd`; the `Palette` autoload only loads it and resolves entries. No inline
  colour anywhere else, neither in `.gd` nor in `.tscn`: components and scenes build their
  `StyleBox` from `Palette.color(<export>)`. Add a new named hex entry in both the enum and the
  exports, at the end, instead of a literal.
- The palette is capped at ten colours plus red and green. Element-specific variants are per-node
  enum exports, not new palette entries; state colours (status, Wi-Fi, focus, unread, late) stay
  runtime-resolved. `PaletteData.Colors` order is append-only because the enum value is what scenes
  store.
- MCP `godot` recovery does not need an OpenCode restart: `opencode api post
  "/api/experimental/mcp/godot/disconnect?location[directory]=<project>"` then the same with
  `connect`. The addon accepts one client only, so disconnect other directories first
  (`C:\Users\Admin`); OpenCode marks the server failed after one timed-out handshake and never
  retries on its own.
- Layout convention: `scripts/` holds code only (`managers/`, `controllers/`, `components/`,
  `tests/`), `scenes/` mirrors that tree with `.tscn` only, and `assets/`, `data/`, `theme/`,
  `addons/`, `docs/` sit at the root. A new component or controller creates the folder in both
  trees; a scene's script path always points into `scripts/`.
- The palette landed as `theme/palette_data.gd` (`PaletteData`, `enum Colors` + `Color` exports),
  `theme/palette.tres` and a facade `scripts/managers/palette.gd` (`colors`, `color(entry)`,
  `load_from`, `using_fallback`). `Palette.colors.<name>` reads a fixed entry; `Palette.color(<export>)` is the
  path for anything an element can choose. `TASKBAR_BUTTON_MINIMIZED_ALPHA` and `TASKBAR_ALPHA`
  stay on the facade: they are alphas, not colours. The headless `_test_palette` guards the literal
  scan (allowlist: the facade and the data script), the enum/exports coherence and the fallback.
- Editor preview: `Palette` and every controller/component are `@tool`. Their `_ready` applies the
  palette and returns when `Engine.is_editor_hint()`, so managers, timers and signals never run in
  the editor; `_input` is guarded the same way. Theme overrides are not serialized by
  `PackedScene`, but direct properties are: `background.color` is reset to `Color.WHITE` on
  `NOTIFICATION_EDITOR_PRE_SAVE` (the only non-palette colour, editor-only) and reapplied on
  `NOTIFICATION_EDITOR_POST_SAVE`. Live refresh is driven by `addons/palette_preview`, an editor
  plugin (`@tool` is mandatory on `EditorPlugin` scripts) that listens to
  `EditorInspector.property_edited` and calls `_apply_palette()` on every node of the edited scene;
  this covers both export edits and palette resource edits. No per-frame polling or 180 setters.
- Headless tests: run the 4.7 Steam binary
  (`C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe`)
  with `--headless --path <project> res://scenes/tests/test_scene.tscn`. It loads the addon without the
  `MCPGameBridge` workaround and keeps the global class cache current, so a new `class_name` is
  found. The winget `godot_console.exe` is 4.4.1 and cannot parse the addon; do not use it. Exit
  code is 1 when a test fails.
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

## 2026-10-23 — Editor palette preview through tool scripts

Scenes used to show Godot defaults (a white desktop) because the palette was only applied by
`_ready()` at runtime. The `Palette` autoload and every controller and component are now `@tool`,
so opening a scene in the editor applies the same colours without launching the game.

Each `_ready()` starts with an editor branch: apply the palette, then return. That keeps managers,
timers, signals, refresh calls and node creation out of the editor. Components only build their
styles or load their textures; they no longer touch `size`, `custom_minimum_size`, `tooltip_text`
or the title text in the editor. `_input()` is also guarded so editor mouse events never drag or
resize a previewed node.

Saving an open scene would serialize direct property writes. Theme overrides are not serialized by
`PackedScene` (checked), so only `background.color` matters: `desktop_controller` and
`login_controller` reset it to `Color.WHITE` on `NOTIFICATION_EDITOR_PRE_SAVE` and reapply the
palette on `NOTIFICATION_EDITOR_POST_SAVE`. No palette colour reaches a `.tscn`.

Files: `scripts/managers/palette.gd`, the 10 controllers under `scripts/controllers/`, the 3
components under `scripts/components/`, `addons/palette_preview/`, `project.godot`, `changes.md`.

Out of scope: styled preview of runtime-built rows and lists, an inspector plugin, and a custom
editor dock.
Docs invalidated: `docs/api/Palette.md`, `docs/Architecture.md` (colour convention, editor mode).

## 2026-10-23 — Project layout split by kind

Split the flat `managers/`, `controllers/`, `components/` and `tests/` roots into a code tree and a
scene tree. `scripts/` now holds every `.gd` (`managers/`, `controllers/`, `components/`, `tests/`)
and `scenes/` mirrors that tree for `.tscn` only, so a component or controller keeps one folder name
in both; `assets/` gathers the app icon and the Wi-Fi SVG icons that used to live inside
`components/wifi/icons/`. `addons/`, `data/`, `theme/` and `docs/` are unchanged.

All `res://` references were rewritten in `project.godot`, `.tscn`, `.gd`, `.tres` and `.import`
files (autoloads, preloads, `run/main_scene`, `config/icon`). The literal-colour test now skips any
directory named `tests` instead of the removed `res://tests` path. Class names, node names and scene
contents are untouched; no file was rewritten beyond its path strings.

Files: every moved `.gd`, `.tscn`, `.uid` and `.import`, `project.godot`, `scripts/tests/test_scene.gd`,
`ROADMAP.md`.

Out of scope: moving `data/`, `theme/` or `docs/` content, renaming classes or nodes, splitting the
larger scenes, and adding an autoload subfolder. Docs invalidated: `docs/Architecture.md` (folder
layout, autoload paths), `docs/Index.md`, `docs/api/Index.md` and every `docs/api/*.md` page that
quotes a `res://` path (`Palette.md`, `Applications.md`, `DesktopShell.md`, `AuthManager.md`,
`ClockManager.md`, `CommissionEditor.md`, `CommissionManager.md`, `MailManager.md`,
`SyncManager.md`).

## 2026-10-23 — Editable palette and per-element colour choices

Replaced the 50-constant palette with `PaletteData`, a typed resource saved as
`theme/palette.tres` and edited in the inspector. The palette is capped at ten colours plus red and
green (background, surface, surface_raised, border, text, text_strong, text_muted, accent, hover,
pressed, danger, success): the former per-surface variants that only differed by a few hex digits
now share one entry. `PaletteData` also carries `enum Colors`, whose names mirror the exports and
whose order is append-only because a scene stores the enum value. The `Palette` autoload became a
facade: it loads the resource, exposes `colors`, resolves an entry with `color(entry)`, and falls
back to the built-in defaults with a warning when the file is missing, unreadable or of another
type; `TASKBAR_ALPHA` and `TASKBAR_BUTTON_MINIMIZED_ALPHA` stay on the facade since they are alphas.

Every controller and component now exposes one `PaletteData.Colors` export per styled element — and
per state where the palette has distinct entries — grouped in the inspector. Action buttons resolve
their background and text from those exports; hover and pressed are derived with
`lightened`/`darkened` because the compact palette has no per-colour state variants. State-driven
colours (status, Wi-Fi, focused title, unread, late delivery) still resolve at runtime.

Files: `theme/palette_data.gd`, `theme/palette.tres`, `managers/palette.gd`, every controller and
component under `controllers/` and `components/`, `tests/test_scene.gd`, `ROADMAP.md`.

`_test_palette` keeps one test for the system: it scans sources for literals outside the facade and
the data script, checks that every enum entry resolves and matches the exported colour count, covers
the missing and wrong-type fallbacks, and round-trips an edited resource through `user://`.

Out of scope: in-game colour picker, live theme switching, user-created themes, per-profile
palettes, per-node binding scripts, more than twelve colours.
Docs invalidated: `docs/api/Palette.md`, `docs/Architecture.md` (autoload table, folder layout,
colour convention), `docs/api/Applications.md`.

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

