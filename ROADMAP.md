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
    `res://data/commissions.json`; the distant default is
    `https://raw.githubusercontent.com/Drawmynd/studraw-desktop/main/data/commissions.json`.
  - Merge by commission id: unknown ids become offers, already seen ids never duplicate.
    A higher `version` refreshes offers that are still pending; accepted, refused and archived
    ones are left untouched. Last good payload is cached in `user://commissions_cache.json`.
- **Dev access**: local profiles in `user://profiles.json`, passwords stored as SHA-256 hex.
  One `admin` profile is seeded as `admin` / `admin`, is the only admin, and can never be deleted;
  every created profile is non-admin. Passwords and pseudos are editable from the Profil app.
  Gameplay gate, not real security.

## Out of scope

- Drawing canvas, layers, artwork export.
- Multiplayer, online player accounts, server backend.
- Web or mobile deployment.
- Prices, payments, negotiation, economy.
- Localisation beyond French.

## Working machine

- Godot 4.7 with the project opened; `git` in `PATH` and a credential manager for publication.
- The public repository and its raw source address are configured (see Fixed decisions).
- Player data lives under `user://`; the install folder is never written to.

## Stack

- Godot 4.7, renderer Mobile (light for a 2D UI app), feature tag switched to Desktop.
- Layout follows the godot skill: `managers/` (autoloads, `.gd` only),
  `controllers/` and `components/` (paired `.gd` + `.tscn`), main scene = a controller.

## Data models

Canonical schemas live in the wiki: [Commissions source](docs/data/CommissionsSource.md),
[Player save](docs/data/PlayerSave.md), [Profiles](docs/data/Profiles.md) and
[Configuration and caches](docs/data/Configuration.md). Commissions are denormalised for
receivers; `client_id` / `type_id` only serve the source editor.

## Shipped base

- Desktop shell with taskbar, live clock, notifications, Wi-Fi indicator and reusable windows
  (drag, resize, maximize, minimize).
- Courrier app with inbox, archive, unread state, reading pane, offer accept and refuse.
- Commission lifecycle with real-time deadlines, reminders, success, failure and per-profile
  persistence.
- Shared source read locally or over HTTPS, cached and merged by id and version.
- Local profiles, administrator gate, login screen and per-profile saves.
- Source editor for clients, types and commissions, staging draft, validation and publication.
- Git publication with repository, remote and branch validation, conditional commit and push.

## Phases

Each phase is one logical change / one commit. Acceptance is written as observable behaviour.
Phases are ordered by priority; identifiers stay stable across reordering.

### M9 — Image delivery and gallery

- Delivery view from an active or finished commission: pick an image, preview it letterboxed
  (contain, never cropped), replace or clear it before sending.
- Accept PNG, JPG and WebP under a size cap; copy the file under
  `user://profiles/<id>/deliveries/<commission_id>/` and refuse unsupported or oversized files.
- Delivering before the deadline marks success and sends the success mail; a passed deadline fails
  the commission but still accepts the image, marked « livré trop tard ». A finished commission
  accepts a delivery without changing its status.
- Galerie app with a thumbnail grid, a list view and a full-size viewer, showing client, type,
  delivery date and the late marker, per profile.
- Acceptance: the preview and the gallery viewer render the exact delivered image; an on-time
  delivery appears in the galerie; a late delivery appears with the late marker; unsupported files
  are refused.
- Out of scope: cropping, editing, multiple images per commission, video, cloud storage.

### M15 — Editable palette

Decision: one typed `PaletteData` Resource saved as `res://theme/palette.tres` and edited in the
inspector, plus one `enum Colors` on the same class so every element picks its entry from a
dropdown.

- The palette is capped at ten colours plus red and green: background, surface, surface_raised,
  border, text, text_strong, text_muted, accent, hover, pressed, danger, success. Semantic variants
  that only differed by a few hex digits share one entry.
- `PaletteData` holds one `Color` export per entry, grouped by surface, and an `enum Colors` with
  the same names and order. The order is append-only: reordering would silently remap the enum
  values stored in scenes.
- `Palette` stays a facade: it loads the resource, exposes `Palette.colors`, resolves an entry with
  `Palette.color(entry)` and falls back to the built-in defaults when the resource is missing,
  unreadable or of another type, reporting the fallback.
- Every controller and component exposes one palette export per element, and per state where the
  palette has distinct entries; coloured action buttons derive hover and pressed from their base
  colour. State-driven colours (status, Wi-Fi, focus, unread, late) stay resolved at runtime.
- Acceptance: every colour is editable from the inspector, every element's colour is chosen from
  the enum in the inspector, no colour literal remains outside the resource and its defaults, and a
  corrupt palette does not prevent startup.
- Out of scope: in-game colour picker, live theme switching, user-created themes, per-profile
  palettes, a palette larger than twelve colours.

### M8 — Mail experience

- A coloured notification for every new mail (offer, reminder, success, failure, info), matched
  to the mail kind; toasts queue instead of overwriting each other.
- Unread badge on the Courrier button, fed by the unread count and cleared as mails are read.
- Inbox actions: mark unread again, restore an archived mail to the inbox. Archiving stays the
  only removal path.
- Acceptance: a new info mail notifies and bumps the badge, reading the last unread mail clears
  the badge, and an archived mail can return to the inbox.

### M10 — Desktop layout

Merges the former window-snapping and application-window-resizing items.

- Dragging a window near the left or right edge snaps it to half the usable work area with a
  preview; dragging it away restores its previous geometry.
- The application window resizes freely with a minimum usable size; desktop, taskbar,
  notifications and open windows reflow and clamp into the new work area.
- Window geometry is clamped after a resize or a maximize.
- Acceptance: a window snaps and restores, and every app stays usable after resizing the OS
  window.
- Out of scope: quarter-screen corners, keyboard shortcuts, multi-monitor rules, remembered
  layout.

### M11 — Progress and statistics

- Statistiques app: totals, success rate, average completion time, per-type breakdown, current
  and best streak.
- A streak counts consecutive local days with at least one delivered commission.
- A weekly goal (delivered commissions) configurable per profile and shown on the desktop.
- Acceptance: completing or failing a commission updates every figure immediately and survives a
  restart; a missed day resets the current streak.
- Out of scope: XP, levels, currency, leaderboards.

### M12 — Content variety and client history

- A commission carries a difficulty tag (easy / normal / hard), visible in the offer and the
  source editor.
- The reading pane shows the client's history from the connected profile: completed count and
  last delivery date.
- A commission can declare a follow-up; a success offers it exactly once, a failure does not.
- Acceptance: difficulty is visible end to end, history only reflects the connected profile, and
  a follow-up is offered once after success.
- Out of scope: prices, negotiation, branching dialogue, automatic authoring.

### M13 — Accessibility and input

- Full keyboard navigation across the taskbar, open windows, lists and forms, with a visible
  focus state.
- Shortcuts: close the focused window, cycle windows, open Courrier and Commandes.
- A UI scale setting for interface text and spacing, persisted per machine.
- Reduced motion: no window or toast animation when enabled.
- Acceptance: every app is reachable and usable without a mouse, and the scale setting applies
  immediately and survives a restart.
- Out of scope: screen-reader support, colour-blind palettes, localisation.

### M14 — Data safety and portability

- Rotating backup of each profile save; an unreadable save falls back to the last valid backup
  instead of an empty state.
- Export and import a profile save as JSON for backup or machine transfer.
- A profile reset with explicit confirmation that clears saves but keeps the profile.
- Acceptance: a corrupted save recovers, export and import round-trip, and a reset leaves a
  usable empty profile.
- Out of scope: cloud sync, automatic off-machine backup.

### M16 — Windows release

- Windows export preset with app icon, version and metadata; tests and the development MCP addon
  excluded from the exported build.
- Portable zip release; saves stay under `user://`, and the app starts on a clean Windows account
  with the seeded administrator.
- A release checklist: version bump, changelog entry, smoke test on a clean profile.
- Acceptance: the exported build runs on a clean Windows account, opens the seeded administrator,
  and writes nothing into the install folder.
- Out of scope: installer or MSIX, auto-update, code signing.

## Risks

- `res://` is read-only in an exported build: runtime writes stay under `user://`, and publication
  targets a configured clone.
- Client-side password hashes are a gameplay gate, not real authentication.
- The repository must stay public; the raw fetch cannot carry a token.
- Git publication is blocking (`OS.execute`): a slow push freezes the app until git returns.
- Image delivery grows player saves; M9 must cap image size and keep copies per profile.

## Quality bar

- One test per durable system, plus one per inter-system interaction. New behaviour extends the
  existing test rather than adding a sibling.
- The headless test scene passes before a phase is accepted.
- No comments in code; colours come from the palette; identifiers are English, UI copy French.
