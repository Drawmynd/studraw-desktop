# Changes

## Memories

- Studraw is a drawing-motivation app (fake artist studio desktop), not a drawing tool.
  The player draws elsewhere; the app only motivates. Recording this so a later session
  does not propose adding a canvas.
- `docs/` is not written unless asked. Working log is `changes.md`; phases live in
  `ROADMAP.md` at the project root.

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
