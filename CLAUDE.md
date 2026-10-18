# Plasma Command Monitor — project notes for Claude

A KDE Plasma 6 plasmoid (`com.drvy.commandmonitor`) that runs user-defined
shell commands on independent refresh intervals and shows their colored
output in the panel and in a popup/desktop list. See `README.md` for the
user-facing feature description; this file is about how the codebase
works and the non-obvious things that were learned building it.

## Environment

- Target: Plasma 6 (tested on 6.7.5, CachyOS/Arch).
- Dev tools: `plasmoidviewer` and `kpackagetool6` come from the
  `plasma-sdk` package (not installed by default — `sudo pacman -S
  plasma-sdk`).
- `qdbus6` (not `qdbus`) is the Qt6 D-Bus CLI on this system; useful for
  scripting widget placement without clicking through the GUI:
  ```sh
  qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript '
  var d = desktops()[0];      // or panels()[0]
  var w = d.addWidget("com.drvy.commandmonitor");
  '
  ```

## Dev loop

```sh
./install.sh preview   # plasmoidviewer, no install needed, fastest iteration
./install.sh install   # first install (kpackagetool6 -i)
./install.sh upgrade   # reinstall after edits (kpackagetool6 -u)
```

**Important:** once a widget instance is already placed on a panel or the
desktop, editing `main.qml`/`CommandDelegate.qml`/`FullRepresentation.qml`
and running `./install.sh upgrade` does **not** hot-reload that running
instance. You must remove it and re-add it (or restart plasmashell) to
see changes. The Configure dialog (`configGeneral.qml`) DOES seem to
reload live more often, but when in doubt, remove/re-add.

Check for QML errors after every change with:
```sh
timeout 6 plasmoidviewer -a "$(pwd)/com.drvy.commandmonitor" -f horizontal -l bottomedge
journalctl --user --since "10 seconds ago" | grep -iE "commandmonitor|TypeError|ReferenceError"
```
(`-f horizontal -l bottomedge` makes plasmoidviewer emulate a panel, so
compact/full representation split like a real panel instead of the
default planar/desktop mode.)

## Architecture

- `contents/ui/main.qml` — root `PlasmoidItem`. Owns `commandList`
  (parsed config), `outputMap` (id → latest output), the `executable`
  DataSource (periodic runs) and the `trigger` DataSource (fire-and-forget
  click commands). Builds the compact (panel) representation as a
  `Repeater` of per-command segments.
- `contents/ui/FullRepresentation.qml` / `CommandDelegate.qml` — the
  popup/desktop list view.
- `contents/ui/configGeneral.qml` — the Configure page (`KCM.SimpleKCM`).
- `contents/code/commands.js` — config schema (`parseCommands`,
  `serializeCommands`, `createDefaultEntry`, `clampInterval`). This is
  the single source of truth for the command entry shape — read the
  schema comment at the top before adding a field.
- `contents/code/ansi.js` — ANSI SGR → HTML conversion, plain-text color
  rules, and `stripAnsi` (used for clipboard copy).

## Hard-won gotchas

- **`metadata.json` needs a top-level `"KPackageStructure": "Plasma/Applet"`
  key.** Without it, `kpackagetool6` installs the package "successfully"
  but plasmashell logs `KPackageStructure ... does not match requested
  format "Plasma/Applet"` and the widget loses core shell integration —
  concretely, right-click stopped showing the standard Configure/Remove
  menu. This was the very first, hardest bug to track down this session.
- **Import path is `org.kde.plasma.plasma5support`**, not
  `org.kde.plasma5support`. The module lives under
  `org/kde/plasma/plasma5support/` on disk; the shorter name (used in
  some outdated examples) doesn't exist and fails silently-ish (module
  not installed error, easy to misdiagnose as something else).
- **`expanded` lives on the `PlasmoidItem` (`root`/the applet's own root
  item), not on the `Plasmoid` attached property.** `Plasmoid.expanded`
  doesn't exist; use `root.expanded` / bare `expanded` inside the root
  item, and `onExpandedChanged` directly on the `PlasmoidItem`, not via
  `Connections { target: Plasmoid }`.
- **Don't consume right-click yourself.** Early versions handled
  right-click with a `MouseArea(acceptedButtons: Qt.RightButton)` that
  popped up a custom `QQC2.Menu` — this fully replaced Plasma's own
  context menu, so "Configure..."/"Remove this widget" became
  unreachable anywhere the MouseArea covered. Fixed by using
  `Plasmoid.contextualActions: [ PlasmaCore.Action { ... } ]` instead
  (a real, if oddly `isReadonly: true`-marked, list property — assigning
  a QML list literal to it works via `QQmlListProperty`'s append, see
  `org.kde.plasma.systemmonitor`'s `main.qml` for a canonical example).
  Track "which command was right-clicked" with a plain `HoverHandler`
  (non-consuming) updating a `contextCommand` property, not with the
  MouseArea itself.
- **Don't rebuild the Repeater model every tick.** `outputMap` changes on
  every single command refresh. Filtering `commandList` into a new
  array (e.g. `commandList.filter(isPanelVisible)`) as the `Repeater`'s
  `model` meant a brand new array *instance* every tick, which rebuilds
  every delegate (icon, label, colors) from scratch — this was the
  actual cause of a "label color randomly disappears" bug that looked
  like a rendering glitch but was really full delegate churn. Fix: keep
  `model: root.commandList` (stable, only replaced on real config
  reload) and put any per-tick-dependent logic (visibility, "hide when
  empty") into a `visible: root.isPanelVisible(modelData)` binding on
  each delegate instead of filtering the model array.
- **`QQC2.Dialog` doesn't reliably size itself to tall/dynamic content.**
  A "Save/Cancel" `Dialog` with a growing form (icon picker, color
  fields, style toggles, click command, color rules...) kept rendering
  its footer buttons overlapping the middle of the content instead of
  below it, no matter how the width/height bindings were tuned. Switched
  to `Kirigami.OverlaySheet` (with a custom `footer: RowLayout { ... }`
  since it has no `standardButtons`), which handles scrolling/sizing
  correctly out of the box. If a config dialog needs to scroll, reach
  for `OverlaySheet` first, don't fight `Dialog`.
- **A non-zero exit code isn't necessarily an "error."** Originally
  showed a red "exit N" badge whenever `exitCode !== 0`; removed it after
  it flagged a perfectly normal command (`test`, which returns 1 with no
  args) as broken. There's no reliable way to distinguish "genuine
  failure" from "expected non-zero" from the exit code alone, so the
  widget doesn't attempt it — empty output just shows a dim
  "(no output)" placeholder instead.
- **Third-party panel tools can override colors.** A "Panel Colorizer"
  widget (`luisbocanegra.panel.colorizer`, if installed) recolors
  everything sitting in the panel, including this widget's icon/label —
  but not the popup, since that's a separate window outside its reach.
  If a user reports "my configured color doesn't show in the panel but
  does in the popup," check for that plugin before assuming a bug here.

## Conventions

- SPDX headers (`SPDX-FileCopyrightText` / `SPDX-License-Identifier`) on
  every source file. In `.pragma library` JS files, the `.pragma
  library` line must stay the very first line — put the SPDX comment
  right after it, not before.
- All user-facing strings in QML wrapped in `i18n()`/`i18nc()`. These
  functions are injected into every Plasma applet's QML context
  automatically (via `KLocalizedContext`) — no import needed. They are
  **not** available in plain `.pragma library` JS files, so
  `commands.js`/`ansi.js` don't use them; only literal UI-chrome strings
  in the `.qml` files need wrapping. Data strings (e.g. a new command's
  default name "New command") are deliberately left unwrapped since
  they're user-edited data, not UI text.
- Git: local repo, no remote. `user.email` is set locally (in this
  repo's `.git/config`, not global) to `dyordanov@drvy.net`, distinct
  from the global/work email — don't let a global config change leak in
  here.

## Known limitations / possible future work

- No drag-and-drop reordering in the config UI, only up/down buttons
  (`page.moveCommand`) — fine for small lists, would want real DnD for
  many commands.
- The executable engine keys sources by literal command text,
  so two commands with the identical command string share one
  underlying timer/process slot (`findDuplicateCommandTexts` in
  `commands.js` exists to detect this but isn't wired into the config UI
  as a visible warning yet).
- No automated tests; verification so far has been manual
  (`plasmoidviewer` + journal grepping + a few standalone Node scripts
  to unit-test `commands.js`/`ansi.js` logic outside of QML).
