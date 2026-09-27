import QtQuick
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

    Plasma5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        interval: 0

        onNewData: function (sourceName, data) {
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
    }

    // Fire-and-forget runner for per-command "click commands". Kept
    // separate from the periodic `executable` source above so that running
    // one never disturbs the connected/interval state of a periodic command
    // that happens to share the same command text.
    Plasma5Support.DataSource {
        id: trigger
        engine: "executable"
        connectedSources: []

        onNewData: function (sourceName) {
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
            trigger.connectSource(cmd.clickCommand);
        }
    }

    function copyOutput(cmd) {
        var out = outputMap[cmd.id];
        if (out && out.plainText) {
            copyToClipboard(out.plainText);
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

    function connectCommand(cmd) {
        if (cmd.enabled && cmd.command) {
            executable.connectSource(cmd.command, cmd.intervalMs);
        }
    }

    function disconnectAllSources() {
        var sources = executable.connectedSources.slice();
        sources.forEach(function (source) {
            executable.disconnectSource(source);
        });
    }

    function connectAll() {
        commandList.forEach(connectCommand);
    }

    // A command is only worth pausing while collapsed if nothing is
    // relying on it staying live, i.e. it's not currently rendered in the
    // panel text.
    function isPausable(cmd) {
        return cmd.intervalMs < fastCommandThresholdMs && cmd.showInPanel === false;
    }

    function disconnectFastCommands() {
        commandList.forEach(function (cmd) {
            if (isPausable(cmd)) {
                executable.disconnectSource(cmd.command);
            }
        });
    }

    function reconnectFastCommands() {
        commandList.forEach(function (cmd) {
            if (isPausable(cmd)) {
                connectCommand(cmd);
            }
        });
    }

    function loadConfig() {
        disconnectAllSources();
        commandList = CommandsJs.parseCommands(Plasmoid.configuration.commandsJson);
        // On the desktop container there is no compact/full split, so
        // everything runs all the time. In a panel, only fast commands get
        // paused while collapsed; slow ones stay connected so their data
        // is fresh whenever the popup is reopened.
        if (isDesktopContainer || expanded) {
            connectAll();
        } else {
            commandList.forEach(function (cmd) {
                if (!isPausable(cmd)) {
                    connectCommand(cmd);
                }
            });
        }
    }

    Component.onCompleted: loadConfig()

    Connections {
        target: Plasmoid.configuration
        function onCommandsJsonChanged() {
            root.loadConfig();
        }
    }

    onExpandedChanged: function () {
        if (isDesktopContainer) {
            return;
        }
        if (root.expanded) {
            reconnectFastCommands();
        } else {
            disconnectFastCommands();
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
            text: "Run command"
            icon.name: "system-run"
            visible: !!(root.contextCommand && root.contextCommand.clickCommand)
            onTriggered: root.runClickCommand(root.contextCommand)
        },
        PlasmaCore.Action {
            text: "Copy to clipboard"
            icon.name: "edit-copy"
            visible: !!root.contextCommand
            onTriggered: root.copyOutput(root.contextCommand)
        }
    ]

    compactRepresentation: Item {
        id: compact

        Layout.fillHeight: true
        Layout.minimumWidth: rowLayout.implicitWidth + Kirigami.Units.smallSpacing * 2
        Layout.preferredWidth: rowLayout.implicitWidth + Kirigami.Units.smallSpacing * 2
        implicitWidth: rowLayout.implicitWidth + Kirigami.Units.smallSpacing * 2
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
                    Layout.leftMargin: Kirigami.Units.smallSpacing
                    Layout.rightMargin: Kirigami.Units.smallSpacing
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
                        text: firstLine || "(no output)"
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
            root.connectCommand(cmd);
        }
        runCommandFn: root.runClickCommand
        copyFn: root.copyOutput
    }
}
