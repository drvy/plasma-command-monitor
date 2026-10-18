# Plasma Command Monitor

A KDE Plasma 6 widget that runs user-defined shell commands, each on its own
refresh interval (1 second to 24 hours), and displays their colored output.

## Requirements

KDE Plasma 6.0 or newer. `plasma-sdk` is only needed for development.

## Install

```sh
git clone https://github.com/drvy/plasma-command-monitor.git
cd plasma-command-monitor
./install.sh install
```

Then add "Command Monitor" from the widget list. A `.plasmoid` file can
be built with `./install.sh package` and installed with
`kpackagetool6 -t Plasma/Applet -i <file>.plasmoid`.

## Design goals

- **Low CPU usage.** Periodic execution is delegated entirely to Plasma's
  `executable` DataEngine (`Plasma5Support.DataSource`), which schedules
  re-runs with its own internal timer. The widget's QML never polls.
- Commands with an interval under 60 seconds are automatically disconnected
  while the panel popup is collapsed, and reconnected (with an immediate
  run) when it's reopened. Desktop-placed widgets are always expanded, so
  this pause doesn't apply there.
- Output coloring supports both ANSI SGR escape codes emitted by the
  command itself, and user-defined plain-text regex color rules, combined
  at whole-line granularity.

## Project layout

```
com.drvy.commandmonitor/
  metadata.json
  contents/
    ui/            main.qml, FullRepresentation.qml, CommandDelegate.qml, configGeneral.qml
    config/         main.xml (KConfigXT), config.qml
    code/           commands.js (config schema helpers), ansi.js (ANSI -> HTML + color rules)
install.sh          install / upgrade / preview helper
```

## Conventions

Following standard KDE practice: every source file carries an SPDX
license header (`SPDX-FileCopyrightText` / `SPDX-License-Identifier`),
and every user-facing string in the QML files is wrapped in `i18n()` /
`i18nc()` so the widget can be translated. Plain-data strings (like a
command's default name) aren't wrapped, since they're user-edited data,
not UI chrome.

## Development

```sh
./install.sh preview   # run standalone via plasmoidviewer, fastest iteration loop
./install.sh install   # install into the local Plasma installation
./install.sh upgrade   # reinstall after making changes
```

## Configuration

Each command has: a name, the shell command line, a refresh interval
(1s–24h), an enabled flag, an optional icon (picked via the standard KDE
icon dialog), a shared color for that icon and the name, independent
bold/italic toggles for the name and for the output text, an optional
"click command", an option to hide the command entirely whenever its
output is empty, and a list of `{pattern, color}` plain-text color rules.
Configuration is edited from the widget's own "Configure..." page and
stored as a single JSON-encoded list.

Each command is rendered as `[icon] name output`, with a small margin
between each part — the icon is simply omitted when not set. Commands
display in the order they're listed on the "Configure..." page; use the
up/down arrows next to each entry there to reorder them.

### Click actions

Clicking a command's output:
- **Left click** (anywhere on the panel) — opens/closes the popup listing
  every command, same as clicking the compact icon.
- **Right click** — always shows Plasma's normal widget menu (which always
  includes "Configure..." and "Remove this widget"), with "Run command"
  (only shown if a click command is set for that entry) as the first
  extra item and "Copy to clipboard" as the second, targeting whichever
  command the pointer is currently over.

Click commands run fire-and-forget (no output shown), e.g. `notify-send`,
`xdg-open`, or `systemctl restart something`. Each command has its own
independent click command — this is not shared/global.

## License

[MIT](LICENSE)
