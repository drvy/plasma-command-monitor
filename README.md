<div align="center">

# 🖥️ Command Monitor

**Tiny shell commands, big panel energy.** ✨

A KDE Plasma 6 widget that runs your own shell commands on their own
schedules and shows the (colorful!) output right in your panel or desktop.

![Plasma 6](https://img.shields.io/badge/KDE%20Plasma-6-1d99f3?logo=kde&logoColor=white)
![License: MIT](https://img.shields.io/badge/license-MIT-green)

</div>

## 🌈 What can it do?

- ⏱️ **Every command has its own timer**, from 1 second to 24 hours.
- 🎨 **Colors everywhere:** ANSI colors from your commands, plus your own
  regex color rules (`error` → red, `ok` → green, you decide).
- 🧩 **Make each entry yours:** icon, name color, bold/italic, hide it when
  its output is empty.
- 👆 **Click actions:** attach a command to each entry (`notify-send`,
  `xdg-open`, `systemctl restart ...`).
- 📋 **Right-click → copy** any command's output to the clipboard.
- 🔄 **Refresh on demand** from the popup list.
- 🪶 **Light on CPU:** Plasma's own engine schedules the runs, the QML never
  polls, and fast commands pause while the popup is closed.

## 📦 Install

```sh
git clone https://github.com/drvy/plasma-command-monitor.git
cd plasma-command-monitor
./install.sh install
```

Then add **Command Monitor** from the widget list. Needs KDE Plasma 6.0 or
newer.

Prefer a package? `./install.sh package` builds a `.plasmoid` you can install
with `kpackagetool6 -t Plasma/Applet -i <file>.plasmoid`.

## 🔧 Setting it up

Right-click the widget → **Configure...** and add some commands. Each one has:

| Option | What it does |
| --- | --- |
| Name / command | What to show and what to run |
| Interval | 1s to 24h |
| Icon & color | Shared by the icon and the name |
| Bold / italic | Independent for the name and the output |
| Click command | Runs when you pick "Run command" from the right-click menu |
| Hide when empty | No output, no clutter |
| Color rules | `{pattern, color}` regex rules for plain-text output |

Each entry shows up as `[icon] name output`, in the order of the list (use the
arrows to reorder).

**Click behavior:** left click opens the popup with every command. Right click
keeps Plasma's usual menu (Configure, Remove...) and adds **Run command** and
**Copy to clipboard** for whichever entry is under the pointer.

> ℹ️ Click commands are fire-and-forget: their output isn't shown.

## 🛠️ Hacking on it

```sh
./install.sh preview   # standalone plasmoidviewer, fastest loop
./install.sh upgrade   # reinstall after edits
```

`plasmoidviewer` comes from `plasma-sdk`. Architecture notes and gotchas live
in [`CLAUDE.md`](CLAUDE.md); see [`CONTRIBUTING.md`](CONTRIBUTING.md) before
opening a PR. Every source file has an SPDX header and every UI string goes
through `i18n()`, so translations are welcome. 🌍

## 📄 License

[MIT](LICENSE) © Dragomir Yordanov
