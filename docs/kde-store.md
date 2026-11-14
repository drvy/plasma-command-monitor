# KDE Store listing

Text and checklist for publishing on <https://store.kde.org>
(category: *Plasma 6 Extensions* → *Plasma Widgets*).

## Fields

- **Name:** Command Monitor
- **Version:** match `metadata.json` (`KPlugin.Version`)
- **License:** MIT
- **Source / homepage:** https://github.com/drvy/plasma-command-monitor
- **Summary:** Run shell commands on their own timers and show their colored output in your panel.

## Description

Command Monitor runs your own shell commands, each on its own refresh
interval (1 second to 24 hours), and shows their output in the panel, the
popup or on the desktop.

- ANSI colors from the command itself, plus regex color rules
- Per-command icon, color, bold/italic and hide-when-empty
- Click commands, copy output to clipboard, refresh on demand
- Light on CPU: scheduling is done by Plasma's own engine

Requires KDE Plasma 6.0 or newer.

## Release steps

1. Bump `KPlugin.Version` in `metadata.json` and add a `CHANGELOG.md` entry.
2. `./install.sh package` → `dist/com.drvy.commandmonitor-<version>.plasmoid`.
3. Upload the `.plasmoid` as the product file (or a new version of it).
4. Tag the release (`git tag -a vX.Y.Z`) and attach the same file on GitHub.
