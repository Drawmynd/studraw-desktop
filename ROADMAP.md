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
  - Client: fetch over HTTPS raw (`raw.githubusercontent.com`), no git needed.
  - Dev: in-game editor writes the JSON into a local clone, then pushes via `git` CLI
    (`OS.execute`), using the machine's credential manager.
  - Source configured in `user://sync_config.json`: `mode` (`local` | `remote`), `local_path`,
    `remote_url`, `sync_interval_minutes` (0 disables periodic sync). Default: local
    `res://data/commissions.json`, so the app works before the public repo exists.
  - Merge by commission id: unknown ids become offers, already seen ids never duplicate.
    A higher `version` refreshes offers that are still pending; accepted, refused and archived
    ones are left untouched. Last good payload is cached in `user://commissions_cache.json`.
- **Dev password**: SHA-256 hash stored as a constant. Gameplay gate, not real security.

## Out of scope

- Drawing canvas, layers, export.
- Multiplayer, online player accounts, server backend.
- Web deployment.

## Prerequisites (user side)

- `git init` + initial commit in the project.
- A **public** GitHub repo + its raw URL for `data/commissions.json`. Not needed before M5's
  `remote` mode is enabled: `local` mode reads `res://data/commissions.json`.
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
          "client": "...", "sender": "...",
          "description": "...", "mail_request": "...", "mail_success": "...",
          "mail_failure": "..." }
      ] }

`client` is the human or company commissioning the work; `sender` is the mail sender and may
differ from the client (e.g. `prenom@entreprise.fr`). Mails carry a `sender` field.

`user://save.json` (player state, never shared):

    { "mails": [ { "id": "...", "sender": "...", "subject": "...", "body": "...",
                   "read": false, "archived": false, "type": "commission_offer",
                   "commission": { ... } } ],
      "commissions": [ { "id": "uuid", "status": "active|success|failed",
                         "accepted_at": 0, "deadline": 0 } ],
      "refused": [ "uuid" ],
      "seen_commissions": [ "uuid" ] }

`user://sync_config.json` (player machine): sync source, see Fixed decisions.
`user://commissions_cache.json`: last successfully fetched payload.
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
- `SyncManager`: local file or HTTPS raw, configured in `user://sync_config.json`, fetch at
  startup and every `sync_interval_minutes`.
- Parse, cache to `user://commissions_cache.json`, offline fallback to cache.
- Merge by id into `CommissionManager`: unknown ids create a `commission_offer` mail once
  (`seen_commissions`), a higher `version` refreshes pending offers only, duplicates are
  impossible. No commission is ever removed by a sync.
- Dev console edits the sync config and triggers a sync manually.
- Done when: a commission added to the source shows up as a single mail, and editing a pending
  commission with a higher `version` updates it without creating a second mail.

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

### M8 — Mail notifications and icon badges
- Notify on every new mail (offer, success, failure, reminder), not only new commission offers.
- Unread badge (pastille) on the Courrier app button, cleared when the mails are read.
- Done when: a new mail shows a notification and a badge, and the badge clears once read.

### M9 — Commission delivery with an image, and a gallery app
- Clicking a commission opens a delivery view where the player attaches an image.
- Delivering before the deadline completes the commission (success mail); a deadline already
  passed fails it, without a delivery.
- A galerie app lists the delivered commissions with their image and date.
- Done when: a commission is delivered with an image in time (success) or late (failure), and the
  image is listed in the galerie.

## Risks

- `res://` is read-only in an exported build → dev push must target a configured local
  clone, not the packed project.
- Client-side password hash is not real authentication.
- The repo must be public, otherwise the raw fetch leaks a token.

## Proposed tests (to validate before writing)

- `AuthManager.verify`: correct password → true, wrong → false.
- `CommissionManager.accept`: `deadline == accepted_at + duration_minutes * 60` (override or type default).
- Expiry → status `failed` + exactly one failure mail.
- Sync merge: only unknown ids produce a "new commission" mail; version guard and cache.
- Sync + commissions: pending offer refreshed on a higher version, accepted / refused / archived
  untouched.
- Sync + mails: offer mail shape (unread, unarchived, sender, client), no duplicate mail ids.
- Cheat + sync: config round-trip and manual sync status.
- `save.json` round-trip: write then read returns identical state.
