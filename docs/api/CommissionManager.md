[Studraw](../Index.md) / [API](Index.md) / CommissionManager

# CommissionManager

## Overview

Autoload owning the commission lifecycle: offers, acceptance, refusal, completion, expiry,
reminders and the persisted commission state. It owns the `commissions`, `refused` and
`seen_commissions` keys of the player save and merges a shared source into them without ever
removing a commission.

## Handlers

| Handler | Role |
| --- | --- |
| `commissions_changed` | any commission state changed |
| `commission_accepted` / `commission_refused` | lifecycle signals |
| `commission_completed` / `commission_failed` | terminal signals |
| `commission_reminder(id, hours)` | reminder fired |
| `accept(commission, now)` | start an active commission and compute its deadline |
| `refuse(id)` | remember a refusal |
| `complete(id)` | finish an active commission and send its success mail |
| `check_deadlines(now)` | expire, remind, or nothing |
| `get_commission(id)` | state copy, or the last known definition |
| `get_active_commissions()` | active only, soonest deadline first |
| `get_all_commissions()` | all states, soonest deadline first |
| `is_refused(id)` / `has_seen(id)` | merge guards |
| `has_open_offer(commission)` | already accepted, refused or completed |
| `get_duration_minutes(commission)` | resolved duration |
| `create_offer(commission)` | merge entry point for an unknown id |
| `refresh_offer(commission)` | refresh a still-pending offer mail |
| `clear_all()` | dev reset |
| `load_state()` / `save_state()` | persistence |

## Flow

Acceptance stores the definition, resolves the duration (override in minutes, otherwise the
type default), computes `deadline = accepted_at + duration_minutes * 60`, marks the commission
active and saves. The minute tick calls `check_deadlines()`: past the deadline the commission
fails and one failure mail is sent; within 24 hours and then within one hour, one reminder mail
is sent per threshold. Completion requires an active commission and sends one success mail.

An offer enters through `create_offer()`: an id is ignored when already seen, already accepted,
completed or refused. Otherwise it is marked seen and one unread, unarchived offer mail is
added. `refresh_offer()` only updates the offer mail of a commission that is still pending and
not archived.

## Error handling

Accepting a known id is idempotent. Completing a non-active commission, refreshing a mail that
is missing or archived, and creating an offer with an empty id are refused silently. Missing
mail copy falls back to generated success and failure bodies. An unreadable save starts empty.

## Rules

- A commission is never removed by a merge or by archiving its mail.
- Reminder and terminal mails are emitted once, guarded by per-state flags.
- Deadlines use real time through `ClockManager`.
- Accepted, refused and archived commissions are never refreshed by a sync.
