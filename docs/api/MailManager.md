[Studraw](../Index.md) / [API](Index.md) / MailManager

# MailManager

## Overview

Autoload holding the inbox. A mail is never destroyed: it is read or unread, in the inbox or
archived. The manager owns the `mails` key of the player save and preserves every other key.

## Handlers

| Handler | Role |
| --- | --- |
| `mails_changed` | any mail state changed |
| `get_mails(include_archived)` | defensive copies, newest first |
| `get_mail(id)` | defensive copy or empty |
| `get_unread_count()` | unread mails outside the archive |
| `add_mail(mail)` | append a normalised mail, generated id when missing |
| `update_mail(id, changes)` | merge changes without resetting read or archived |
| `mark_read(id)` | idempotent |
| `archive_mail(id)` | move to archive, idempotent |
| `ensure_welcome_mail()` | seed the welcome mail once |
| `clear_all()` | dev reset |
| `load_state()` / `save_state()` | persistence |

## Flow

The screen calls `ensure_welcome_mail()` before its first refresh, then listens to
`mails_changed`. Selecting a mail marks it read; archiving removes it from the inbox and leaves
it in the archive view. `add_mail()` normalises missing fields (`read`, `archived`, `type`,
`commission`) so older saves keep loading. `update_mail()` rewrites only the provided fields,
which is how a pending offer is refreshed without losing its unread state.

## Error handling

An unreadable or non-object save is ignored and the inbox starts empty. A missing mail makes
read, archive and update no-ops. Mail ids are unique only by construction; the managers
generate deterministic ids for offers, reminders, success and failure.

## Rules

- Archiving is the only removal path exposed to the player.
- Mails never carry mutable commission state; an offer mail carries a snapshot definition.
- Sorting is by `received_at`, newest first.
