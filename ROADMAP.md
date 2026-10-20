# Studraw — Roadmap

Drawing-motivation app: a fake artist's studio desktop. The player receives drawing
commissions by mail, accepts them with a deadline, and is scored by a real-time clock.
The app does not draw for the player — it motivates them, like a fitness app.

## Fixed decisions

- **Platform**: Desktop (Windows), mouse + keyboard.
- **UI language**: French (content and labels).
- **Drawing**: out of scope. The player draws elsewhere.
- **Deadlines**: real time, persisted across sessions. Durations are expressed in minutes and
  resolved from a `type -> minutes` dictionary unless the commission sets a `duree` override;
  on accept, `deadline = now + duration_minutes * 60`.
- **Shared content**: `commissions.json` in a **public** git repo.
  - Client: fetch over HTTPS raw at startup (`raw.githubusercontent.com`), no git needed.
  - Dev: in-game editor writes the JSON into a local clone, then pushes via `git` CLI
    (`OS.execute`), using the machine's credential manager.
- **Dev password**: SHA-256 hash stored as a constant. Gameplay gate, not real security.

## Out of scope

- Drawing canvas, layers, export.
- Multiplayer, online player accounts, server backend.
- Web deployment.

## Prerequisites (user side)

- `git init` + initial commit in the project.
- A **public** GitHub repo + its raw URL for `data/commissions.json`.
- `git` installed and credentials configured on the dev machine.

## Stack

- Godot 4.7, renderer Mobile (light for a 2D UI app), feature tag switched to Desktop.
- Layout follows the godot skill: `managers/` (autoloads, `.gd` only),
  `controllers/` and `components/` (paired `.gd` + `.tscn`), main scene = a controller.

## Data models

`data/commissions.json` (shared, written by dev, read by all):

    { "version": 3, "updated_at": 1234567890,
      "commissions": [
        { "id": "uuid", "title": "...", "type": "illustration", "duration": null,
          "description": "...", "mail_request": "...", "mail_success": "...",
          "mail_failure": "..." }
      ] }

`user://save.json` (player state, never shared):

    { "mails": [...],
      "commissions": [ { "id": "uuid", "statut": "active|success|failed",
                         "accepted_at": 0, "deadline": 0 } ] }

`user://dev_config.json` (dev machine only): path to the local git clone.

## Milestones

Each milestone is one logical change / one commit.

### M1 — Project setup
- Switch `project.godot` to Desktop, 1280x720 window, register autoloads.
- Create folder tree and manager skeletons.
- `main.tscn` with `DesktopController`: fake desktop background, taskbar with a
  real-time clock.
- Done when: the app launches on a desktop background with a live clock.

### M2 — Window system
- `WindowComponent`: draggable by title bar, close / minimize, reusable.
- Window manager in `DesktopController`: open, focus (z-index), close.
- Done when: icons open a draggable window that closes cleanly.

### M3 — Mail app
- `MailManager`: inbox list, read / unread state, persistence.
- `MailAppController`: mail list + reading pane.
- Archive: deleting a mail moves it to the archive, never destroys it.
- Local only, no sync yet.
- Done when: a hardcoded mail appears, is readable, can be archived, and read state
  survives restart.

### M4 — Commission lifecycle
- `CommissionManager`: accept, complete, deadline computation, states.
- `ClockManager`: real clock, 1-minute tick, reminder (H-24h, H-1h) and expiry signals.
- Success mail on completion, failure mail on expiry, reminder mails.
- Save / load player state.
- Done when: accept → countdown → complete (success) or expiry (failure) both work
  and persist across restarts.

### M5 — Sync (read)
- `SyncManager.fetch()`: HTTPS raw → parse → cache to `user://`.
- Merge unknown commission ids into `CommissionManager`, each fires a
  "new commission" mail. Offline fallback to cache.
- Done when: a new commission pushed to the repo shows up as mail on next launch.

### M6 — Dev account + editor
- `AuthManager`: SHA-256 constant, `verify()`, `is_dev_session`.
- `DevConsoleController`: login, commission form (title, type, duration override,
  description, mail request, mail success, mail failure), writes `data/commissions.json`.
- Done when: correct password unlocks the editor and a new commission is written to disk.

### M7 — Dev publish
- `SyncManager.push()`: `git add` / `commit` / `push` via `OS.execute`, using the clone
  path from `user://dev_config.json`.
- Publish button shows git stdout / stderr in the console.
- Done when: pressing Publish commits and pushes, and a client picks it up (M5).

## Risks

- `res://` is read-only in an exported build → dev push must target a configured local
  clone, not the packed project.
- Client-side password hash is not real authentication.
- The repo must be public, otherwise the raw fetch leaks a token.

## Proposed tests (to validate before writing)

- `AuthManager.verify`: correct password → true, wrong → false.
- `CommissionManager.accept`: `deadline == accepted_at + duration_minutes * 60` (override or type default).
- Expiry → status `failed` + exactly one failure mail.
- Sync merge: only unknown ids produce a "new commission" mail.
- `save.json` round-trip: write then read returns identical state.
