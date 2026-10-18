// SPDX-FileCopyrightText: 2026 Dragomir Yordanov <dyordanov@drvy.net>
// SPDX-License-Identifier: MIT

import QtQuick
import QtQml
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as Plasma5Support
import "../code/commands.js" as CommandsJs
import "../code/ansi.js" as AnsiJs

PlasmoidItem {
    id: root

    // Commands with intervalMs below this threshold are considered "fast"
    // and get paused while the popup is collapsed, to save CPU.
    readonly property int fastCommandThresholdMs: 60000

    property var commandList: []
    // id -> { richHtml, richFirstLine, stderr, exitCode, lastRun }
    property var outputMap: ({})

    readonly property bool isDesktopContainer: Plasmoid.formFactor === PlasmaCore.Types.Planar
        || Plasmoid.formFactor === PlasmaCore.Types.Application

    // IMPORTANT: Plasma5Support.DataSource.connectSource() only ever takes a
    // single argument (see plasma5supportplugin.qmltypes) -- there is no
    // "connectSource(source, interval)" overload in this Plasma6 API,
    // despite that having been valid on Plasma 5. Passing a second argument
    // is silently accepted by QML but does nothing: it does NOT set up a
    // per-source polling interval. The engine only re-executes a source
    // automatically when the *DataSource itself* has a non-zero `interval`
    // property, which applies to every source connected to that DataSource.
    // (Confirmed with an isolated qml6 test: connectSource(cmd, ms) ran the
    // command exactly once and never again, no matter how long we waited or
    // how the watched file changed; a DataSource with `interval: 2000` and a
    // plain connectSource(cmd) re-ran it correctly every 2s.)
    //
    // Since commands here can each have their own intervalMs, one DataSource
    // is instantiated per distinct interval value actually in use, and every
    // command with that interval is connected to it.
    function handleNewData(sourceName, data) {
        var cmd = root.commandForSource(sourceName);
        if (!cmd) {
            return;
        }
        var stdout = data["stdout"] || "";
        var stderr = data["stderr"] || "";
        var newlineIndex = stdout.indexOf("\n");
        var firstLine = newlineIndex === -1 ? stdout : stdout.substring(0, newlineIndex);
        root.setOutput(cmd.id, {
            richHtml: AnsiJs.toRichText(stdout, cmd.colorRules),
            richFirstLine: AnsiJs.toRichText(firstLine, cmd.colorRules),
            plainText: AnsiJs.stripAnsi(stdout),
            stderr: stderr,
            exitCode: data["exit code"],
            lastRun: Date.now()
        });
    }

    // A command is only worth pausing while collapsed if nothing is
    // relying on it staying live, i.e. it's not currently rendered in the
    // panel text.
    function isPausable(cmd) {
        return cmd.intervalMs < fastCommandThresholdMs && cmd.showInPanel === false;
    }

    function shouldPoll(cmd) {
        if (!cmd.enabled || !cmd.command) {
            return false;
        }
        return isDesktopContainer || root.expanded || !isPausable(cmd);
    }

    // Commands that should be actively polled right now, and the distinct
    // set of their intervals -- both recomputed only when commandList or
    // expanded/isDesktopContainer actually change (real, infrequent events),
    // never per-tick.
    property var activeCommands: commandList.filter(shouldPoll)

    property var intervalBuckets: {
        var seen = {};
        var out = [];
        activeCommands.forEach(function (cmd) {
            if (!seen[cmd.intervalMs]) {
                seen[cmd.intervalMs] = true;
                out.push(cmd.intervalMs);
            }
        });
        return out;
    }

    function commandTextsForInterval(ms) {
        return activeCommands
            .filter(function (cmd) { return cmd.intervalMs === ms; })
            .map(function (cmd) { return cmd.command; });
    }

    // One real, engine-driven periodic DataSource per distinct interval.
    Instantiator {
        model: root.intervalBuckets

        delegate: Plasma5Support.DataSource {
            required property int modelData
            engine: "executable"
            interval: modelData
            // Assigning the whole list lets the DataSource itself diff old
            // vs new and connect/disconnect only what changed -- no need to
            // manage connectSource/disconnectSource by hand here.
            connectedSources: root.commandTextsForInterval(modelData)

            onNewData: function (sourceName, data) {
                root.handleNewData(sourceName, data);
            }
        }
    }

    // One-shot runner, used both for fire-and-forget "click commands" and
    // for the explicit per-command "Refresh" action. Unlike the periodic
    // pollers above, this never sets an interval: it connects a source,
    // waits for its single result, and disconnects immediately -- the same
    // shape already relied on for click commands, which is what makes
    // disconnect+reconnect safe to repeat here (there's always a real gap,
    // at least one full run, between a disconnect and the next connect of
    // the same source; reconnecting a source in the same tick it was just
    // disconnected on, which the periodic pollers above never do, is what
    // previously produced stale cached data in testing).
    Plasma5Support.DataSource {
        id: oneShot
        engine: "executable"
        connectedSources: []

        onNewData: function (sourceName, data) {
            root.handleNewData(sourceName, data);
            disconnectSource(sourceName);
        }
    }

    // Hidden helper used to reach the system clipboard from QML without
    // requiring an extra import.
    TextEdit {
        id: clipboardHelper
        visible: false
    }

    function copyToClipboard(text) {
        clipboardHelper.text = text;
        clipboardHelper.selectAll();
        clipboardHelper.copy();
        clipboardHelper.text = "";
    }

    function runClickCommand(cmd) {
        if (cmd.clickCommand) {
            oneShot.connectSource(cmd.clickCommand);
        }
    }

    // Explicit per-command "Refresh" action: run it once, right now,
    // outside of its regular polling interval.
    function forceRefresh(cmd) {
        if (cmd.command) {
            oneShot.connectSource(cmd.command);
        }
    }

    function copyOutput(cmd) {
        var out = outputMap[cmd.id];
        if (out && out.plainText) {
            // Trailing blank lines/whitespace are just how the command's
            // output happened to end, not something worth pasting.
            copyToClipboard(out.plainText.replace(/\s+$/, ""));
        }
    }

    function commandForSource(source) {
        for (var i = 0; i < commandList.length; i++) {
            if (commandList[i].command === source) {
                return commandList[i];
            }
        }
        return null;
    }

    function setOutput(id, patch) {
        var copy = Object.assign({}, outputMap);
        copy[id] = Object.assign({}, copy[id] || {}, patch);
        outputMap = copy;
    }

    function loadConfig() {
        commandList = CommandsJs.parseCommands(Plasmoid.configuration.commandsJson);
    }

    Component.onCompleted: loadConfig()

    Connections {
        target: Plasmoid.configuration
        function onCommandsJsonChanged() {
            root.loadConfig();
        }
    }

    preferredRepresentation: isDesktopContainer ? fullRepresentation : null

    function hasOutput(cmd) {
        var out = outputMap[cmd.id];
        return !!(out && out.plainText && out.plainText.trim().length > 0);
    }

    // Per-command visibility checks used directly in delegates' `visible`
    // bindings, rather than filtering commandList into a new array — the
    // latter would rebuild every Repeater/ListView delegate (icon, label,
    // colors and all) on every single command tick, since both depend on
    // outputMap. Keeping the model array itself stable (only replaced when
    // commandList actually changes, i.e. on config reload) avoids that churn.
    function isPanelVisible(cmd) {
        return cmd.enabled && cmd.showInPanel !== false && (!cmd.hideWhenEmpty || hasOutput(cmd));
    }

    function isListVisible(cmd) {
        return !cmd.hideWhenEmpty || hasOutput(cmd);
    }

    // Drives the fallback icon's visibility; a cheap boolean recompute, not
    // a model rebuild, so it's fine that it depends on outputMap.
    property bool anyPanelSegmentVisible: commandList.some(function (cmd) {
        return root.isPanelVisible(cmd);
    })

    // The last command the pointer was over, used to target the two
    // command-specific entries added below to Plasma's own right-click
    // menu. Using Plasmoid.contextualActions (instead of popping up our
    // own Menu and consuming the right-click) means "Configure..." and
    // "Remove this widget" always keep showing on right click, with our
    // entries merged in rather than replacing them.
    property var contextCommand: null

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Run command")
            icon.name: "system-run"
            visible: !!(root.contextCommand && root.contextCommand.clickCommand)
            onTriggered: root.runClickCommand(root.contextCommand)
        },
        PlasmaCore.Action {
            text: i18n("Copy to clipboard")
            icon.name: "edit-copy"
            visible: !!root.contextCommand
            onTriggered: root.copyOutput(root.contextCommand)
        }
    ]

    compactRepresentation: Item {
        id: compact

        Layout.fillHeight: true
        Layout.minimumWidth: rowLayout.implicitWidth
        Layout.preferredWidth: rowLayout.implicitWidth
        implicitWidth: rowLayout.implicitWidth
        implicitHeight: Kirigami.Units.iconSizes.small

        RowLayout {
            id: rowLayout
            anchors.fill: parent
            spacing: Kirigami.Units.smallSpacing

            // Fallback icon: only shown when there is nothing else to
            // display (no per-command segments visible), so the popup
            // always stays reachable even with zero configured/visible
            // commands. Once segments are showing, clicking any of them
            // opens the popup the same way — no fixed icon takes up space.
            MouseArea {
                visible: !root.anyPanelSegmentVisible
                Layout.preferredWidth: visible ? Kirigami.Units.iconSizes.small : 0
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                Layout.alignment: Qt.AlignVCenter
                onClicked: root.expanded = !root.expanded

                Kirigami.Icon {
                    anchors.fill: parent
                    source: Plasmoid.configuration.compactIcon || "utilities-terminal"
                }
            }

            Repeater {
                model: root.commandList

                delegate: RowLayout {
                    id: segment
                    required property var modelData
                    visible: root.isPanelVisible(modelData)
                    Layout.alignment: Qt.AlignVCenter
                    spacing: Kirigami.Units.smallSpacing

                    Kirigami.Icon {
                        visible: !!segment.modelData.icon
                        source: segment.modelData.icon
                        color: segment.modelData.labelColor || Kirigami.Theme.textColor
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: Kirigami.Units.iconSizes.small
                        Layout.alignment: Qt.AlignVCenter
                    }

                    PlasmaComponents3.Label {
                        text: segment.modelData.name
                        color: segment.modelData.labelColor || Kirigami.Theme.textColor
                        font.bold: segment.modelData.labelBold !== false
                        font.italic: !!segment.modelData.labelItalic
                        Layout.alignment: Qt.AlignVCenter
                    }

                    PlasmaComponents3.Label {
                        readonly property string firstLine: (root.outputMap[segment.modelData.id] && root.outputMap[segment.modelData.id].richFirstLine) || ""
                        text: firstLine || i18n("(no output)")
                        opacity: firstLine ? 1 : 0.5
                        textFormat: Text.RichText
                        font.family: "monospace"
                        font.bold: !!segment.modelData.outputBold
                        font.italic: !!segment.modelData.outputItalic
                        elide: Text.ElideRight
                        Layout.alignment: Qt.AlignVCenter
                        Layout.maximumWidth: Kirigami.Units.gridUnit * 16
                    }

                    HoverHandler {
                        onHoveredChanged: if (hovered) root.contextCommand = segment.modelData
                    }

                    // Left click just opens the popup (same as clicking the
                    // fallback icon); the per-command "Run command" /
                    // "Copy to clipboard" actions live in the right-click
                    // menu only (see Plasmoid.contextualActions above).
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.expanded = !root.expanded
                    }
                }
            }
        }
    }

    fullRepresentation: FullRepresentation {
        commandList: root.commandList
        outputMap: root.outputMap
        isVisibleFn: root.isListVisible
        onRefreshRequested: function (cmd) {
            root.forceRefresh(cmd);
        }
        runCommandFn: root.runClickCommand
        copyFn: root.copyOutput
    }
}
