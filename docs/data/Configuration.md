[Studraw](../Index.md) / Data / Configuration and caches

# Configuration and caches

## Purpose

Four machine-local files that are not player content: the sync source configuration, the last
good payload, the source-editor draft and the publication settings. None of them is part of the
shared repository, and none is per profile.

## Sync configuration

`user://sync_config.json`, written by the dev console and the Wi-Fi indicator.

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| `mode` | string | `local` | `local` or `remote`; any other value falls back to `local` |
| `local_path` | string | `res://data/commissions.json` | source read in local mode and used as publication source |
| `remote_url` | string | the public raw URL | read in remote mode |
| `sync_interval_minutes` | integer | 30 | 0 disables periodic sync; clamped to 0 or more |

The default remote is
`https://raw.githubusercontent.com/Drawmynd/studraw-desktop/main/data/commissions.json`. An
unreadable file falls back to defaults without being rewritten. A successful fetch restarts the
timer, so the interval is measured from the end of the last attempt.

## Payload cache

`user://commissions_cache.json`, written after every accepted payload.

| Field | Type | Notes |
| --- | --- | --- |
| `version` | integer | version of the cached payload |
| `updated_at` | integer | timestamp carried by the source |
| `commissions` | array | valid flattened commissions only |

The cache only stores commissions: clients and types are authoring data and never reach a
receiver. It is applied when the source is missing or unreachable, with the source still reported
as unreachable. A payload older than the cache is ignored.

## Source draft

`user://pending_commissions.json`, written by the source editor after every accepted change.

| Field | Type | Notes |
| --- | --- | --- |
| `version` | integer | same version as the last loaded or published source |
| `updated_at` | integer | same timestamp as the last loaded or published source |
| `clients` | array | full authoring list |
| `types` | array | full authoring list |
| `commissions` | array | full authoring list |

The draft is global to the machine, not per profile, and it survives login changes. It is
preferred over the source when the editor opens. Publication rewrites the source but does not
delete the draft, so the admin keeps working on the same version.

## Publication configuration

`user://dev_config.json`, written by the dev console.

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| `repo_path` | string | project root | absolute path, or a path Godot can globalise |
| `remote` | string | `origin` | git remote name |
| `branch` | string | `main` | branch pushed |

A blank value in the file keeps the default. The source must live inside `repo_path`; the
publication stages only that file.

## Error handling

An unreadable configuration falls back to defaults in memory and is not overwritten until the
player saves it. An unreadable cache behaves as an empty cache. An unreadable draft makes the
editor refuse to load rather than overwrite it. An unreadable publication configuration keeps the
built-in repository, remote and branch.

## Out of scope

No per-profile sync settings, no credential storage (git credential manager handles it), no
history of past payloads, no draft merging between machines.
