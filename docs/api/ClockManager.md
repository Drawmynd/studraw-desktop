[Studraw](../Index.md) / [API](Index.md) / ClockManager

# ClockManager

## Overview

Autoload that turns engine frames into two application-wide ticks. It is the only clock the
rest of the app observes; deadlines and countdowns use real system time, never simulated time.

## Handlers

| Handler | Role |
| --- | --- |
| `second_tick` | emitted once per accumulated second |
| `minute_tick` | emitted once per accumulated minute |
| `get_time_string()` | local `HH:MM:SS` for the taskbar |
| `get_unix_time()` | current real Unix time |

## Flow

Frame deltas accumulate in separate second and minute accumulators. A `while` loop drains each
accumulator, so a long frame emits the missing ticks instead of skipping them. The taskbar
refreshes on the second tick; `CommissionManager` checks deadlines on the minute tick.

## Error handling

There is none: the manager never reads a file or a network source. Frame stalls simply produce
several ticks in a row.

## Rules

- Real time only. No pause, speed-up or time travel is exposed.
- Consumers must tolerate several ticks in one frame.
