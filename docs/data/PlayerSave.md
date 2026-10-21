[Studraw](../Index.md) / Data / Player save

# Player save

## Purpose

One file per profile holding the mail inbox and the commission state. It is never shared and
never leaves the machine. `MailManager` and `CommissionManager` both write it and preserve the
keys owned by the other.

## Location

`user://profiles/<profile id>/save.json`. The legacy `user://save.json` is copied once into the
administrator profile when that profile has no save yet.

## Fields

| Field | Type | Notes |
| --- | --- | --- |
| `mails` | array | inbox and archive |
| `commissions` | array | accepted commissions with their terminal states |
| `refused` | array of strings | commission ids refused by the player |
| `seen_commissions` | array of strings | ids already offered, never offered twice |

## Mail

| Field | Type | Notes |
| --- | --- | --- |
| `id` | string | deterministic for offers, reminders and outcomes |
| `sender` | string | sender address or name |
| `subject` | string | French |
| `body` | string | French |
| `received_at` | integer | Unix time |
| `read` | boolean | cleared by opening the mail |
| `archived` | boolean | the only removal path |
| `type` | string | `commission_offer` or `info` |
| `commission` | object | snapshot definition for an offer, empty otherwise |

Deterministic mail ids: `offre_<id>`, `rappel_24_<id>`, `rappel_1_<id>`, `succes_<id>`,
`echec_<id>`, plus `bienvenue` for the welcome mail.

## Commission state

| Field | Type | Notes |
| --- | --- | --- |
| `id` | string | commission id |
| `status` | string | `active`, `success` or `failed` |
| `accepted_at` | integer | Unix time |
| `deadline` | integer | `accepted_at + duration_minutes * 60` |
| `reminded_24` / `reminded_1` | boolean | one mail per threshold |
| `title`, `type`, `client`, `sender`, `description` | string | snapshot fields |
| `duration` | integer or null | original override |
| `duration_minutes` | integer | resolved duration |
| `mail_request`, `mail_success`, `mail_failure` | string | snapshot copy |

## Prose

A commission keeps a snapshot of its definition, so a later source refresh cannot rewrite an
accepted commission. The seen list makes an offer unique even after its mail is archived; the
refused list prevents a new offer for a refused id. A completed or failed commission stays in
the file but leaves the active list.

## Out of scope

No window layout, no clock state, no draft (the draft is global to the machine), no deletion of
terminal commissions and no schema version field.
