[Studraw](Index.md) / Changelog

# Changelog

## 0.1.0 — 2026-10-21

First complete desktop loop: log in, read commissions, accept one with a real deadline, and
publish new commissions from an administrator session.

### Added

- Desktop shell with a live clock, taskbar, app buttons and notification queue.
- Draggable, resizable, maximizable and minimizable windows that stay inside the work area and
  scroll their content instead of widening.
- Courrier app: inbox, archive, unread state, reading pane, offer accept and refuse.
- Commission lifecycle: acceptance, real-time deadlines, H-24 and H-1 reminders, completion,
  expiry, success and failure mails, persisted per profile.
- Shared commission source in `data/commissions.json`, read locally or over HTTPS raw, cached,
  merged by id, refreshed by source version without touching accepted or archived commissions.
- Wi-Fi indicator with local, distant and error states, clickable to switch source mode.
- Local profiles with SHA-256 passwords, login screen, administrator reveal, Profil app, profile
  creation, credential change and deletion, and one player save per profile.
- Source editor for clients, types and commissions with migration of legacy flat commissions,
  validation, a staging draft, and publication that bumps the source version.
- Git publication from the dev console and the editor: repository, remote and branch validation,
  conditional commit and push, git journal, public project repository as the shared source.
- Dev console with test-state cheats, source and publication configuration, manual sync, the last
  sync result and a raw local file viewer.

### Known limits

- No drawing canvas: the player draws outside the app.
- No image delivery and no gallery (M9).
- No unread badge and no notification for every mail kind (M8).
- The application window itself is not yet sized for free resizing (M11), and windows do not snap
  to half screen (M10).
- Passwords are a gameplay gate, not real authentication.
