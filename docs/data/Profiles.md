[Studraw](../Index.md) / Data / Profiles

# Profiles

## Purpose

The machine-local list of people allowed to use the app, with their hashed passwords and their
role. Profiles are not game content: they never travel to the shared source, and there is no
online identity.

## Location

`user://profiles.json`, plus one directory per profile under `user://profiles/<id>/`.

## Fields

| Field | Type | Notes |
| --- | --- | --- |
| `version` | integer | schema version, currently 1 |
| `profiles` | array | one object per profile |

## Profile

| Field | Type | Notes |
| --- | --- | --- |
| `id` | string | `prof_<unixtime>_<hex4>`, or `prof_admin` for the seed |
| `pseudo` | string | unique, case-insensitive |
| `password_hash` | string | SHA-256 hex of the password |
| `is_admin` | boolean | true only for the seeded administrator |
| `created_at` | integer | Unix time |
| `updated_at` | integer | Unix time, refreshed by a credential change |

## Seeded administrator

`admin` / `admin`, id `prof_admin`, `is_admin` true. It is created when the file is missing or
contains no valid profile. The file is never rewritten when it exists but is unreadable, so a
corrupt file is not silently replaced. The administrator is the only profile allowed to delete
another profile and the only one that cannot be deleted.

## Prose

`get_profiles()` sorts the administrator first and the others by pseudo, by role then name; the
login screen filters the administrator out until its title is clicked five times. A created
profile is always standard. Deleting a profile removes its player save; its empty directory may
remain on disk.

The password hash is a gameplay gate, not a security boundary: anyone with access to the file can
read the hashes, and there is no rate limiting.

## Out of scope

No avatar, no email, no password reset, no session persistence across launches, no profile
export, no remote account.
