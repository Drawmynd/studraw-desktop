[Studraw](../Index.md) / [API](Index.md) / Desktop shell

# Desktop shell

## Overview

The desktop is the main scene after login. It owns the taskbar, the windows layer, the clock,
the Wi-Fi indicator and the notification queue. The window component is its only reusable UI
primitive; every app is content placed inside a window.

## Handlers

### DesktopController

| Handler | Role |
| --- | --- |
| `open_window(title, content)` | instantiate, cascade, clamp, register and focus a window |
| `_focus_window(window)` | unfocus the others, bring one to the front |
| `_on_window_closed(window)` | drop the taskbar button |
| `_update_admin_visibility()` | show Éditeur and Console dev only for an admin session |
| `_update_wifi_state()` | local, distant or error state from the sync manager |
| `_show_notification(message)` | queue a non-modal notification |
| logout | close the session and return to the login scene |

### WindowComponent

| Handler | Role |
| --- | --- |
| `setup(title, content)` | install content, wrap labels, track the content minimum size |
| `focus()` / `set_focused(value)` | z-order and title bar styling |
| `maximize()` / `restore_from_maximize()` / `toggle_maximize()` | work-area maximisation |
| `minimize()` / `restore()` | hide and show, with the taskbar button alpha |
| `clamp_into_work_area()` | keep the window inside the desktop above the taskbar |

## Flow

The desktop instantiates a window, adds the app content, positions it on a cascade, clamps it,
connects its signals, adds a taskbar button and focuses it. A click anywhere on a window focuses
it. A taskbar button restores a minimized window and focuses it. Closing emits `closed`, frees
the window and removes its button.

Content is added inside a scroll container. Its root is expanded to fill the window, its
minimum size is derived from full-rect children, labels in vertical layouts wrap smartly, and
every label added later to a container receives the same treatment. Horizontal overflow is
cropped, vertical overflow scrolls.

The Wi-Fi indicator shows local (barred, grey), distant (green) or error (red). Error wins when
the last sync of the current mode failed; forcing the distant state overrides it. Clicking
toggles local and distant, saves the configuration and fetches immediately.

## Error handling

Opening an app without its manager still shows the window with an empty or disabled state. A
minimized window is hidden but keeps its taskbar entry. A window is always clamped back into the
work area after a resize, a maximize or a viewport change. Notifications queue rather than
overwrite each other.

## Rules

- The taskbar is the only navigation; there are no menus or keyboard shortcuts.
- Content never resizes a window: the window scrolls or crops it.
- Only an admin session sees the editor and the dev console.
- The clock and the countdowns use real time.
