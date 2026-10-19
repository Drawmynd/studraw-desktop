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
