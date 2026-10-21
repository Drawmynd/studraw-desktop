[Studraw](../Index.md) / [API](Index.md) / AuthManager

# AuthManager

## Overview

Autoload owning local profiles and the current session. There is no server and no real
authentication: passwords are SHA-256 hashes compared in memory, purely to gate access and keep
profiles apart. It also owns the per-profile save directory and the one-time migration of the
legacy save.

## Handlers

| Handler | Role |
| --- | --- |
| `profiles_changed` / `session_changed` | profile list or session changed |
| `get_profiles()` / `get_profile(id)` | defensive copies of the profile metadata |
| `get_current_profile()` / `is_authenticated()` | current session |
| `is_dev_session()` | current profile is the administrator |
| `verify(id, password)` | password check without opening a session |
| `authenticate(id, password)` | open a session, emits `session_changed` |
| `logout()` | close the session |
| `create_profile(pseudo, password)` | create a standard profile |
| `change_credentials(id, current, pseudo, password)` | update pseudo and/or password |
| `delete_profile(id, password)` | self-service deletion |
| `delete_profile_as_admin(id, admin_password)` | deletion from the dev console |
| `get_profile_save_path(id)` | path of a profile's player save |
| `migrate_legacy_save()` | copy `save.json` once into the administrator profile |

## Flow

Startup loads `user://profiles.json`. When the file is missing or yields no valid profile, the
seed administrator is created; the file is only written when it did not exist, so an unreadable
file is never overwritten. Profile directories are ensured, then the legacy save is copied into
the administrator profile when that profile has no save yet.

Creating a profile validates the pseudo, its uniqueness (case-insensitive) and a four-character
minimum, then stores the password hash. Changing credentials requires the current password; an
empty new password keeps the old one, an empty new pseudo keeps the old one. Deletion requires
the profile password, or the administrator's password plus an admin session. The only
administrator can never be deleted.

## Error handling

Every mutating handler returns `{ok, id, error}`. Refusals cover: missing or duplicate pseudo,
short password, wrong current password, unknown profile, wrong administrator password, missing
admin session and deleting the last administrator. A successful deletion also removes the
profile's save.

## Rules

- The seeded `admin` profile is the only administrator; created profiles are never admins.
- Profiles are never hard-deleted from another profile's session.
- The password hash is a gameplay gate, not a security boundary.
- The session is not persisted across launches.
