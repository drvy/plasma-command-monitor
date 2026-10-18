import QtQuick
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
    // id -> { richHtml, stderr, exitCode, lastRun }
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
            root.setOutput(cmd.id, {
                richHtml: AnsiJs.toRichText(stdout, cmd.colorRules),
                stderr: stderr,
                exitCode: data["exit code"],
                lastRun: Date.now()
            });
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

    function disconnectFastCommands() {
        commandList.forEach(function (cmd) {
            if (cmd.intervalMs < fastCommandThresholdMs) {
                executable.disconnectSource(cmd.command);
            }
        });
    }

    function reconnectFastCommands() {
        commandList.forEach(function (cmd) {
            if (cmd.intervalMs < fastCommandThresholdMs) {
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
                if (cmd.intervalMs >= fastCommandThresholdMs) {
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

    onExpandedChanged: {
        if (isDesktopContainer) {
            return;
        }
        if (expanded) {
            reconnectFastCommands();
        } else {
            disconnectFastCommands();
        }
    }

    preferredRepresentation: isDesktopContainer ? fullRepresentation : null

    compactRepresentation: MouseArea {
        onClicked: root.expanded = !root.expanded

        Kirigami.Icon {
            anchors.fill: parent
            source: Plasmoid.configuration.compactIcon || "utilities-terminal"
        }
    }

    fullRepresentation: FullRepresentation {
        commandList: root.commandList
        outputMap: root.outputMap
        onRefreshRequested: function (cmd) {
            root.connectCommand(cmd);
        }
    }
}
