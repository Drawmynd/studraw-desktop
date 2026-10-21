# Studraw — Roadmap

Drawing-motivation app: a fake artist's studio desktop. The player receives drawing
commissions by mail, accepts them with a deadline, and is scored by a real-time clock.
The app does not draw for the player — it motivates them, like a fitness app.

## Fixed decisions

- **Platform**: Desktop (Windows), mouse + keyboard.
- **UI language**: French (content and labels).
- **Drawing**: out of scope. The player draws elsewhere.
- **Deadlines**: real time, persisted across sessions. Durations are expressed in minutes and
  resolved from a `type -> minutes` dictionary unless the commission sets a `duration` override;
  on accept, `deadline = now + duration_minutes * 60`.
- **Shared content**: `commissions.json` in a **public** git repo.
  - Client: fetch over HTTPS raw (`raw.githubusercontent.com`), no git needed.
  - Dev: in-game editor writes the JSON into a local clone, then pushes via `git` CLI
    (`OS.execute`), using the machine's credential manager.
  - Source configured in `user://sync_config.json`: `mode` (`local` | `remote`), `local_path`,
    `remote_url`, `sync_interval_minutes` (0 disables periodic sync). Default: local
    `res://data/commissions.json`, so the app works before the public repo exists; the default
    remote address is
    `https://raw.githubusercontent.com/Drawmynd/studraw-desktop/main/data/commissions.json`.
  - Merge by commission id: unknown ids become offers, already seen ids never duplicate.
    A higher `version` refreshes offers that are still pending; accepted, refused and archived
    ones are left untouched. Last good payload is cached in `user://commissions_cache.json`.
- **Dev access**: local profiles in `user://profiles.json`, passwords stored as SHA-256 hex.
  One `admin` profile is seeded as `admin` / `admin`, is the only admin, and can never be deleted;
  every created profile is non-admin. Passwords and pseudos are editable from the Profil app.
  Gameplay gate, not real security.

## Out of scope

- Drawing canvas, layers, export.
- Multiplayer, online player accounts, server backend.
- Web deployment.

## Prerequisites (user side)

- `git init` + initial commit in the project.
- A **public** GitHub repo + its raw URL for `data/commissions.json`. Not needed before M5's
  `remote` mode is enabled: `local` mode reads `res://data/commissions.json`.
- `git` installed and credentials configured on the dev machine.
- M7 needs a **configured git remote** on the repository; the project has none by default. Create
  the public repo, add it as `origin`, then publish from the dev console.

## Stack

- Godot 4.7, renderer Mobile (light for a 2D UI app), feature tag switched to Desktop.
- Layout follows the godot skill: `managers/` (autoloads, `.gd` only),
  `controllers/` and `components/` (paired `.gd` + `.tscn`), main scene = a controller.

## Data models

`data/commissions.json` (shared, written by dev, read by all):

    { "version": 6, "updated_at": 1234567890,
      "clients": [ { "id": "cli-001", "name": "...", "email": "..." } ],
      "types": [ { "id": "typ-001", "name": "illustration", "duration_minutes": 2880 } ],
      "commissions": [
        { "id": "comm-2026-001", "title": "...", "type": "illustration", "type_id": "typ-001",
          "duration": null, "client": "...", "client_id": "cli-001", "sender": "...",
          "description": "...", "mail_request": "...", "mail_success": "...",
          "mail_failure": "..." }
      ] }

`client` / `sender` / `type` / `duration` are denormalised so receivers never need the `clients`
and `types` lists; `client_id` / `type_id` only serve the source editor.

`user://profiles/<id>/save.json` (player state, one file per profile, never shared):

    { "mails": [ { "id": "...", "sender": "...", "subject": "...", "body": "...",
                   "read": false, "archived": false, "type": "commission_offer",
                   "commission": { ... } } ],
      "commissions": [ { "id": "uuid", "status": "active|success|failed",
                         "accepted_at": 0, "deadline": 0 } ],
      "refused": [ "uuid" ],
      "seen_commissions": [ "uuid" ] }

`user://profiles.json` (profiles and passwords, machine local):

    { "version": 1,
      "profiles": [ { "id": "prof_<unixtime>_<hex4>", "pseudo": "admin",
                      "password_hash": "<sha256 hex>", "is_admin": true,
                      "created_at": 0, "updated_at": 0 } ] }

The legacy `user://save.json` is copied once into the admin profile save so the existing state
survives the switch to per-profile saves.

`user://sync_config.json` (player machine): sync source, see Fixed decisions.
`user://commissions_cache.json`: last successfully fetched payload.
`user://dev_config.json` (dev machine only): path to the local git clone.

## Milestones

Each milestone is one logical change / one commit.

M6 was split into `M6a` and `M6b`: planning added a multi-profile Profil app, a login screen and
per-profile saves, which is more than the original "constant hash dev account + editor". `M6a` is
itself documented as two commits (data and session, then screens) because the auth data layer and
its screens are two logical changes.

Tests follow one rule: one test per durable system, plus one test per inter-system interaction.
No per-behaviour splits.

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

### M6a — Profiles and admin session
- `AuthManager`: local profiles, one seeded `admin` / `admin` profile, SHA-256 passwords, create,
  connect, logout, change pseudo / password, delete. Deleting the only admin is refused; the dev
  console deletes another profile with the admin password as confirmation.
- Login screen at startup: profile list, connect, create, delete.
- Per-profile player state, the legacy `user://save.json` migrating once into the admin profile.
- Desktop gate: Profil always visible; Console dev and Éditeur only during an admin session.
- Documented as two commits: data and session, then screens.
- Done when: a new profile starts with an empty state, the admin finds its migrated state, and the
  dev tools appear only after an admin login.

### M6b — Source editor (clients, types, commissions)
- `CommissionEditor`: loads a working document from a pending draft (`user://pending_commissions.json`)
  or, when no draft exists, from `SyncManager.local_path`, migrating the flat commissions into reusable
  clients (name, email) and types (name, default duration). CRUD for the three families, each guarded by
  the admin session and persisted to the draft after every change; a commission cannot be saved without
  a valid client and type, and a client or type used by a commission cannot be deleted.
- "Valider et publier" writes the whole document to `SyncManager.local_path` (clients, types,
  commissions), bumps `version` and `updated_at`, refuses an unreadable source, then syncs. Deletions
  therefore reach new receivers only: an already-seen commission is never removed by the merge.
- Published commissions stay denormalised (`client`, `sender`, `type`, effective `duration`) so the
  receivers keep working without reading the new element lists.
- Done when: an admin creates, edits and deletes clients, types and commissions, publishes to the
  source, and a new commission arrives as exactly one offer mail.

### M7 — Dev publish (done)
- `SyncManager` loads `user://dev_config.json`: `repo_path` (default: the project root, which
  holds `data/commissions.json`), `remote` (`origin`) and `branch` (`main`).
- `SyncManager.publish()`: admin session required, the configured path must be a git repository and
  the remote must exist, the globalized `local_path` must live inside `repo_path` (one source file,
  no copy), then `git add`, a conditional `chore(data): publish commissions v<N>` commit and
  `git push`. Output is captured (`OS.execute`, blocking) and returned line by line; a failed push
  leaves the local source intact and never creates a partial commit.
- Dev console: "Publication git" section (repository, remote, branch, save, publish) with a
  read-only log of git output.
- Editor "Valider et publier": local source write followed by the git push, status line reporting
  either the published version or the push failure. The full git log stays in the dev console.
- Done when: pressing Publish commits and pushes, and a client picks it up (M5).

### M8 — Mail notifications and icon badges
- Notify on every new mail (offer, success, failure, reminder), not only new commission offers.
- Unread badge (pastille) on the Courrier app button, cleared when the mails are read.
- Toast notifications coloured by type (info / success / failure), with the matching icon accent.
- Done when: a new mail shows a coloured notification and a badge, and the badge clears once read.

### M9 — Commission delivery with an image, and a gallery app
- Clicking a commission opens a delivery view where the player attaches an image.
- Delivering before the deadline completes the commission (success mail); a deadline already
  passed fails it, without a delivery.
- A galerie app lists the delivered commissions with their image and date.
- Done when: a commission is delivered with an image in time (success) or late (failure), and the
  image is listed in the galerie.

### M10 — Window snapping to half screen (documented, not scheduled)
- Dragging a window close to the left or right edge of the screen snaps it automatically to half
  the usable space (taskbar excluded), with a preview while dragging, like Windows.
- Dragging the window away from the edge restores its previous size and position.
- The taskbar and the desktop keep their current behaviour; the window minimum size still applies.
- Out of scope: quarter-screen corners, keyboard shortcuts, multi-monitor edge rules.

### M11 — Resizable application window (documented, not scheduled)
- The application window itself (the OS window hosting the whole project, not a `WindowComponent`)
  can be resized freely by the player, like any desktop application.
- The desktop, taskbar, notifications and open windows adapt to the new size; existing windows are
  clamped back into the work area and the taskbar stays anchored to the bottom.
- A minimum application size keeps every app usable, and the viewport keeps its current
  `canvas_items` / `expand` stretch behaviour.
- Out of scope: fullscreen or borderless toggles, per-monitor DPI rules, remembering the window
  size and position across launches.

## Risks

- `res://` is read-only in an exported build → dev push must target a configured local
  clone, not the packed project.
- Client-side password hash is not real authentication.
- The repo must be public, otherwise the raw fetch leaks a token.

## Proposed tests (to validate before writing)

- `T-AUTH` (system, `AuthManager`): seeded admin, login, profile creation, credential change,
  deletion with the profile password and with the admin password, last-admin guard, persistence,
  unreadable profile file left untouched.
- `T-AUTH-SAVE` (interaction, auth + player state): two profiles never share a save, the legacy
  `save.json` is copied once into the admin profile.
- `T-AUTH-DSK` (interaction, auth + screens): login screen flow, desktop dev buttons only in an
  admin session, deletion from the dev console with the admin password.
- `T-EDIT` (system, `CommissionEditor`): migration of flat commissions into clients and types, CRUD
  refusals (duplicates, invalid duration, referenced client/type), draft kept apart from the source,
  publish (version bump, timestamp, denormalised fields, unreadable source refused), missing source,
  unreadable draft.
- `T-EDIT-SYNC` (interaction, editor + sync): a published commission becomes exactly one offer mail,
  a second sync duplicates nothing, and a published deletion leaves the already-received offers intact.
- `CommissionManager.accept`: `deadline == accepted_at + duration_minutes * 60` (override or type default).
- Expiry → status `failed` + exactly one failure mail.
- Sync merge: only unknown ids produce a "new commission" mail; version guard and cache.
- Sync + commissions: pending offer refreshed on a higher version, accepted / refused / archived
  untouched.
- Sync + mails: offer mail shape (unread, unarchived, sender, client), no duplicate mail ids.
- Cheat + sync: config round-trip and manual sync status.
- `save.json` round-trip: write then read returns identical state.
