[Studraw](../Index.md) / [API](Index.md) / SyncManager

# SyncManager

## Overview

Autoload that feeds the shared commissions into the player state and publishes the source back
to git. It reads either a local file or an HTTPS raw URL, caches the last valid payload, merges
it through `CommissionManager`, and exposes the source configuration, the last sync result and
the publication settings.

## Handlers

| Handler | Role |
| --- | --- |
| `sync_finished(reachable, new_offers)` | one sync attempt finished |
| `mode_changed(mode)` | local/distant mode changed |
| `start()` | first fetch at desktop startup, skipped when headless |
| `fetch()` | one local or remote attempt, never overlapping |
| `apply_payload(payload, write_cache)` | validate, cache and merge |
| `load_cache()` / `save_cache()` | last good payload |
| `load_config()` / `save_config()` | `user://sync_config.json` |
| `set_mode(mode)` | validated mode switch |
| `apply_interval(minutes)` | periodic fetch timer, 0 stops it |
| `get_last_sync_text()` | local timestamp plus success or failure |
| `load_dev_config()` / `save_dev_config()` | `user://dev_config.json` |
| `publish()` | git add, conditional commit, push |

## Flow

Local mode reads `local_path` directly. Remote mode requests `remote_url` with a timeout; an
empty URL is a failed attempt. A completed request must be successful and HTTP 200. Any failure
falls back to the cache, applies it when it exists, and still reports the source as unreachable
so a broken configuration stays visible.

A payload is accepted only when `commissions` is an array of objects carrying an id and a title.
A version lower than the cached version is ignored. Otherwise the payload is cached, unknown ids
create offers, and when the version increased, still-pending offers are refreshed.

Publication validates the administrator session, the repository, its remote, and that the
globalised source lives inside the repository. It stages only the source file, commits only when
that file changed, then pushes to the configured remote and branch. A missing remote fails
before staging. Git output is captured line by line and returned with the result.

## Error handling

Every publication refusal is returned as `{ok: false, error}` with the captured lines. A failed
push does not revert the source file, which the editor already wrote; it leaves the working tree
as it is. An unreadable source is refused rather than overwritten.
An unreadable configuration file falls back to defaults without rewriting it. Remote credentials
are left to the machine's git credential manager; the app does not prompt.

## Rules

- One source of truth: the source file must live inside the configured repository.
- A sync never removes a commission and never duplicates an offer.
- A failed sync still applies the cache, but reports the source as unreachable.
- The mode and interval are configuration, not gameplay; switching mode does not clear state.
- Publication is a development action, reserved to the administrator session.
