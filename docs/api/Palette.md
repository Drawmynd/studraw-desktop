[Studraw](../Index.md) / [API](Index.md) / Palette

# Palette

## Overview

Autoload holding every colour in the application, each under a semantic name. Controllers and
components build their `StyleBox` and font overrides from it; scenes contain no literal colour.
This keeps the fake desktop consistent and makes a visual retune a single-file change.

## Handlers

| Handler | Role |
| --- | --- |
| colour constants | named colours for desktop, taskbar, window, mail, commissions, Wi-Fi, notifications, danger and status |
| `TASKBAR_BUTTON_MINIMIZED_ALPHA` | alpha applied to a minimized window's taskbar button |
| `status_color(kind)` | white for normal status, red for `error` |

## Flow

A controller reads the constants it needs at `_ready`, builds flat style boxes, and applies them
to panels, buttons, fields, lists and labels. Dynamic states use the same constants: a focused
window takes the active title colours, a minimized button takes the minimized alpha, a failed
sync takes the error colour.

## Error handling

`status_color()` falls back to the normal status colour for an unknown kind.

## Rules

- Never write a colour literal outside this file, including in `.tscn`.
- Add a semantic name instead of reusing a colour for a different meaning.
- A test fails the suite if any source file outside the palette contains a colour literal.
