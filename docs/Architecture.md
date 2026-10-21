[Studraw](Index.md) / Architecture

# Architecture

## Purpose

Studraw motivates daily drawing. The player logs into a local profile, reads commissions in a
simulated mail app, accepts one with a real deadline, draws outside the app, then completes the
commission. A shared public repository feeds new commissions into the app; an admin profile also
edits and publishes that source from inside the app.

## Stack and platform

- Godot 4.7, Mobile renderer, Desktop feature tag.
- Windows desktop, mouse and keyboard, French user interface.
- 1280x720 base viewport with `canvas_items` stretch and `expand` aspect.
- No network backend: the shared content is a JSON file served by a public git repository.

## Folder layout

```
managers/       autoload singletons, .gd only
controllers/    screens, each a .gd + .tscn pair
components/     reusable visuals, each a .gd + .tscn pair
data/           shared commission source shipped with the project
tests/          one headless test scene
docs/           this wiki
```

A controller is either the application scene (login, desktop) or the content of a window.
Every screen gets its own scene and controller; there is no shared UI framework beyond the
palette and the window component.

## Autoloads

Registered in `project.godot`, in this order:

| Name | Role |
| --- | --- |
| `ClockManager` | real clock, one-second and one-minute ticks |
| `Palette` | every colour used by the app |
| `AuthManager` | profiles, passwords, session |
| `MailManager` | mail state and persistence |
| `CommissionManager` | commission lifecycle and offer merge |
| `SyncManager` | source fetch, cache, sync config, git publication |
| `CommissionEditor` | staging document, CRUD, source publication |

Managers resolve each other from `/root` on first use and accept an injected dependency for
tests. They are the only place holding mutable player state.

## Application flow

1. `login_controller.tscn` is the main scene. It lists the profiles stored on the machine.
2. A successful login tells `AuthManager` who is connected and wires the player save
   (`user://profiles/<id>/save.json`) into `MailManager` and `CommissionManager`.
3. The desktop scene replaces the login scene. It shows the taskbar, the clock, the Wi-Fi
   state and one button per app.
4. The desktop fetches the shared source once at startup; `SyncManager` then repeats the fetch
   on its configured interval.
5. New commissions become offer mails. Accepting one starts a real-time countdown.
6. Accepting, refusing, completing and expiry are persisted through the per-profile save.
7. Logging out returns to the login screen; the next profile loads its own save.

## Window shell

`DesktopController` owns a `Windows` layer and a taskbar. `open_window()` instantiates a
`WindowComponent`, adds the content, cascades its position, clamps it into the work area,
registers a taskbar button and focuses it. Focusing moves the window to the front and switches
the title bar colours. Closing removes the taskbar button.

`WindowComponent` handles dragging, resizing from its eight edges and corners, maximize and
restore, minimize, focus styling and work-area clamping. Its content is wrapped in a scroll
container: the content is hard-cropped horizontally and scrolls vertically. Labels outside a
horizontal or grid layout wrap automatically, and the minimum size of full-rect content roots
is copied into the scroll container so tall forms remain reachable.

## Shared content flow

- `data/commissions.json` holds clients, types and commissions.
- The source is read either locally (`local_path`) or over HTTPS raw (`remote_url`), and the last
  valid payload is cached.
- `SyncManager` merges by commission id through `CommissionManager`: unknown ids become one
  offer mail, a higher source version refreshes still-pending offers, and accepted, refused or
  archived commissions are never touched.
- An admin edits a staging draft, publishes it into the source file, then pushes that file to
  the configured git remote. Deletions only affect receivers that have not seen the commission
  yet.

## Data ownership

- Player state lives under `user://profiles/<id>/save.json`, written by `MailManager` and
  `CommissionManager`, which preserve each other's keys.
- Profiles and password hashes live in `user://profiles.json`.
- Sync and publication settings live in `user://sync_config.json` and `user://dev_config.json`.
- The staging draft lives in `user://pending_commissions.json`; the published source is only
  written by an explicit publication.

## Conventions

- Identifiers, test messages and documentation are English; UI copy and content are French.
- Field names are never abbreviated.
- Every colour comes from `Palette`; no literal colour exists elsewhere, including scenes.
- No comments in code.
- Managers hold logic and state; controllers only read state, call managers and style their
  scene.
- Tests follow one rule: one test per durable system, plus one per inter-system interaction.

## Deliberately excluded

Drawing canvas, layers, export, multiplayer, online accounts, a server backend, web deployment,
game-time deadlines, a mail search or folders, permanent mail deletion, image delivery until
M9, and any dependency beyond the Godot standard library plus the development MCP addon.
