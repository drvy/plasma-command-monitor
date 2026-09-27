# Plasma Command Monitor

A KDE Plasma 6 widget that runs user-defined shell commands, each on its own
refresh interval (1 second to 24 hours), and displays their colored output.

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

## Development

```sh
./install.sh preview   # run standalone via plasmoidviewer, fastest iteration loop
./install.sh install   # install into the local Plasma installation
./install.sh upgrade   # reinstall after making changes
```

## Configuration

Each command has: a name, the shell command line, a refresh interval
(1s–24h), an enabled flag, and an optional list of `{pattern, color}`
plain-text color rules. Configuration is edited from the widget's own
"Configure..." page and stored as a single JSON-encoded list.
