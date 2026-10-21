[Studraw](../Index.md) / [API](Index.md) / Applications

# Applications

## Overview

Each application is a controller paired with a scene, opened inside a desktop window except the
login screen, which is the application scene before login. Controllers read managers, style
their own scene from the palette, and never write files themselves.

## Applications

| Application | Scene | Role |
| --- | --- | --- |
| Login | `controllers/login` | profile selection, creation, credentials, admin reveal |
| Desktop | `controllers/desktop` | shell, taskbar, windows, notifications |
| Courrier | `controllers/mail` | inbox and archive, reading pane, accept and refuse |
| Commandes | `controllers/commissions` | active commissions with live countdowns |
| Éditeur | `controllers/editor` | source document CRUD and publication |
| Console dev | `controllers/dev` | cheats, sync and publication configuration, profiles |
| Fichier local | `controllers/dev` | read-only view of the configured source file |
| Profil | `controllers/profile` | credential change, deletion, logout |

## Login flow

The screen lists standard profiles. The administrator stays hidden until the title receives five
clicks; revealing it selects it and opens its credentials step. A profile can be created (pseudo,
password and confirmation, minimal length enforced) or selected to open its password step.
A correct password wires the profile save into the mail and commission managers, then replaces
the scene with the desktop. The back actions return to the profile selection.

## Courrier flow

The app seeds the welcome mail, lists the inbox or the archive, and marks a selected mail read.
An offer mail shows accept and refuse while its commission is still pending; both actions archive
the mail, and accepting also creates the active commission. Archiving is available for every
mail in the inbox.

## Éditeur flow

The left panel switches between Commandes, Clients and Types and lists the draft elements. The
right panel edits the selected element or a new one. Saving validates the fields, keeps the
selection, and reports the result in a status line. The publication action validates the whole
document, writes the source, pushes it with git, and syncs on success.

## Console dev flow

Cheats reset the test state or force a reminder, failure or success. The sync section edits the
source configuration and triggers a manual sync. The publication section edits the repository,
remote and branch, publishes with a git journal, and shows the last sync. The profile section
deletes a profile with the administrator password.

## Profil flow

The app first offers three actions. The credential action asks for the new pseudo, password and
confirmation, then for the current password on its own step. The delete action asks for the
password on its own step. The administrator profile cannot be deleted from this app. A successful
deletion removes the profile and its save and returns to the login screen.

## Error handling

Every form reports refusals in a status line, white for normal messages and red for errors.
Buttons are disabled while their action is unavailable, and whole sections are hidden outside
an administrator session. A login failure leaves the player save unwired.

## Rules

- One scene per application; no app embeds another app's screen.
- UI copy is French, identifiers and code are English.
- Administrators are the only profiles with access to the editor, the console and publication.
