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
- To plan (Optimisations, `EXT`): make the palette editable from the editor. Requires a custom
  `Resource` (`class_name PaletteData` with `@export` colours) saved as `res://theme/palette.tres`,
  injected via `@export var palette: PaletteData` on controllers/components, with the autoload
  either loading it or disappearing. A bare autoload script cannot expose `@export` colours; no
  plugin is needed. Deferred for now.

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
to other projects. The tools only reappear after OpenCode itself reconnects to the server.

Invalidated docs pages: none.
