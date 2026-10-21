[Studraw](../Index.md) / [API](Index.md) / CommissionEditor

# CommissionEditor

## Overview

Autoload owning the staging copy of the shared source. An administrator edits clients, types and
commissions in a draft, validates it, and publishes it into the source file and then to git.
Receivers only ever read the flattened commissions, so the client and type lists are an authoring
convenience.

## Handlers

| Handler | Role |
| --- | --- |
| `can_publish()` | administrator session available |
| `load_document()` | draft if present, otherwise the source, migrated |
| `add_client` / `update_client` / `remove_client` | client CRUD |
| `add_type` / `update_type` / `remove_type` | type CRUD, duration in minutes |
| `add_commission` / `update_commission` / `remove_commission` | commission CRUD |
| `validate_document()` | whole-document validation message or empty string |
| `push(now)` | write the source, bump version and timestamp |

## Flow

Loading prefers `user://pending_commissions.json`. Without a draft, the source is read and
migrated: a client per distinct client name (carrying the sender as its email), a type per
distinct type name (legacy defaults win over a per-commission duration), and a stable id for
commissions that had none. Unreadable drafts or sources are refused, never overwritten.

Each mutation requires an admin session, validates its input, updates the draft and saves it
immediately. Renaming a client or a type rewrites the denormalised name and sender of the
commissions that reference it. A client or type used by a commission cannot be deleted. A
commission stores the client and type ids next to the flat client, sender, type and effective
duration.

Publication validates the document, rereads the source (refusing an unreadable one), replaces
the clients, types and commissions arrays, bumps `version`, sets `updated_at`, and saves the
draft. Deletions only affect receivers that have not seen the commission yet.

## Error handling

Refusals cover: no admin session, no loaded document, empty or duplicate names, invalid or
non-positive durations, unknown or referenced clients and types, a missing title or request
message, and an unreadable draft or source. Every mutation returns `{ok, error}`; publication
also returns the new version.

## Rules

- The draft is the only mutable working copy; the source changes only on publication.
- A commission is never saved without a known client and a known type.
- Published commissions stay self-sufficient without the client and type lists.
- Removing an element is refused while a commission references it.
