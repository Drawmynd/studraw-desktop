[Studraw](Index.md) / Features

# Features

## Profiles and session

- Profiles are local to the machine. One seeded administrator (`admin` / `admin`) is the only
  admin and cannot be deleted; every created profile is standard.
- The login screen lists standard profiles first. The administrator is hidden until its title is
  clicked five times, which keeps dev tools out of the everyday flow.
- A profile is created with a pseudo, a password and a confirmation (minimum four characters).
  Passwords are stored as SHA-256 hashes; this is a gameplay gate, not real security.
- The Profil app changes the pseudo and password, or deletes the profile after its password. The
  delete flow and the credential flow each ask for the current password on their own step.
- The taskbar has a "Déconnexion" button. Logging out returns to the login screen without opening
  the Profil app.
- Each profile owns its mail and commission state. The legacy `save.json` is copied once into the
  administrator's profile.

## Desktop shell

- Fake desktop background, bottom taskbar with a live clock, a Wi-Fi indicator and one button per
  app: Courrier, Commandes, Éditeur (admin only), Console dev (admin only), Profil and
  Déconnexion.
- Windows are draggable by their title bar, resizable from their edges and corners, maximizable,
  minimizable to a taskbar button, focused on click, and never leave the work area.
- Window content never widens its window: long text wraps, horizontal overflow is cropped, and
  tall content scrolls vertically.
- Notifications appear for a new offer, a reminder, a success, a failure and an unreachable
  source. They queue and disappear after a few seconds.

## Courrier

- Inbox and archive views, one toggle between them.
- Unread mails show a bullet and a highlighted colour; opening a mail marks it read.
- "Supprimer" archives the selected mail. Nothing is ever destroyed; the archive is the only
  removal path.
- Offer mails show "Accepter" and "Refuser" while the commission is still pending. Accepting
  starts the commission and archives the offer; refusing marks the commission refused and
  archives the offer.
- The reading pane shows the sender and, for an offer, the client behind the mail.
- A welcome mail is seeded on first use.

## Commandes

- Lists active commissions, soonest deadline first, with client, type, duration and a countdown
  refreshed every second.
- Completed and failed commissions leave the list; their mails remain.

## Commission lifecycle

- A commission is defined by id, title, type, optional duration override, client, sender,
  description and its request / success / failure mail bodies.
- Accepted at time T, the deadline is `T + duration_minutes * 60`, where the duration is the
  override when present, otherwise the type default (illustration 2880 min, affiche 1440 min,
  croquis 120 min).
- Reminder mails are sent once at H-24 and once at H-1. Expiry fails the commission and sends one
  failure mail. Completing an active commission marks it successful and sends one success mail.
- All states are persisted immediately and survive restarts.

## Shared commissions and sync

- The source is a JSON document with a `version`, an `updated_at` stamp, and clients, types and
  commissions.
- Local mode reads `local_path` (default `res://data/commissions.json`). Remote mode reads an
  HTTPS raw URL; the default points at the public Studraw repository.
- A successful payload is cached. When the source is missing, invalid or unreachable, the cache
  is applied but the source is still reported as unreachable.
- Synchronisation runs at startup and every configured interval (0 disables it). Fetches never
  overlap.
- Merge is by commission id and never removes a commission. An unknown id creates exactly one
  offer mail. A higher source version refreshes offers that are still pending; accepted, refused
  and archived commissions are untouched. Duplicate ids in one payload produce one offer.
- The Wi-Fi indicator has three states: local (grey, barred), distant (green) and error (red).
  Clicking it toggles local and distant, saves the configuration and fetches immediately.
- The dev console exposes the source configuration, a manual sync, the last sync result, the raw
  local file and a forced distant state.

## Source editor (admin)

- Commandes, Clients and Types share a reusable source document. Clients carry a name and an
  email; types carry a name and a default duration in minutes.
- A commission references a client and a type. Renaming either rewrites the denormalised fields
  of its commissions. A client or type in use cannot be deleted.
- Every change is validated and saved to a staging draft (`user://pending_commissions.json`)
  immediately; the published source stays untouched until publication.
- "Valider et publier" validates the document, writes it to the source, bumps its version and
  timestamp, then pushes it with git.
- Published commissions stay denormalised (client, sender, type, effective duration) so receivers
  never need the client and type lists.
- Deletions only reach receivers that have not seen the commission; the merge never removes an
  existing offer.
- Request, success and failure texts have a drag grip that grows or shrinks their area.

## Publication (admin)

- `user://dev_config.json` stores the repository path (default: the project root), the remote
  (`origin`) and the branch (`main`).
- Publication validates the repository, the remote and that the source lives inside the
  repository, stages only the source file, commits `chore(data): publish commissions v<N>` when
  it changed, then pushes. The console shows the git output line by line.
- A failed push reports the error and leaves the source file as written; a missing remote fails
  before anything is staged, and publication never pulls.
- The full project repository is public, so its `data/commissions.json` is the shared source.

## Dev console (admin)

- Test-state reset (welcome mail, one offer, three active commissions), new offer, and forced
  reminder, failure and success events.
- Sync configuration, publication configuration, publication with its journal, last sync line,
  Wi-Fi forcing, raw local file viewer, and profile deletion with the admin password.

## Not implemented yet

Window snapping to half screen (M10), free resizing behaviour of the application window itself
(M11), commission delivery with an image and the gallery (M9), and the unread badge plus one
notification per mail kind (M8).

## Deliberately excluded

Drawing inside the app, mail search or folders, restoring an archived mail, permanent deletion,
editing received commissions, attachments outside M9, and any online account or server.
