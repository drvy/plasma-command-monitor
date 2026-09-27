import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtQuick.Dialogs as QQDialogs
import org.kde.kirigami as Kirigami
import "../code/commands.js" as CommandsJs

Kirigami.FormLayout {
    id: page

    // Bound by the Plasma config system to the kcfg entries in main.xml.
    property string cfg_commandsJson: "[]"
    property string cfg_compactIcon: "utilities-terminal"

    property var commands: []
    property bool loaded: false

    function reloadFromCfg() {
        commands = CommandsJs.parseCommands(cfg_commandsJson);
        loaded = true;
    }

    function persist() {
        cfg_commandsJson = CommandsJs.serializeCommands(commands);
        // Force the ListView model to refresh even though it's the same array reference.
        commandListView.model = null;
        commandListView.model = commands;
    }

    Component.onCompleted: reloadFromCfg()

    Kirigami.FormData.label: "Compact icon:"
    QQC2.TextField {
        id: iconField
        text: page.cfg_compactIcon
        placeholderText: "utilities-terminal"
        onEditingFinished: page.cfg_compactIcon = text
        Layout.preferredWidth: Kirigami.Units.gridUnit * 12
    }

    Kirigami.Separator {
        Kirigami.FormData.isSection: true
        Kirigami.FormData.label: "Commands"
    }

    Item {
        Kirigami.FormData.isSection: false
        Layout.fillWidth: true
        Layout.preferredHeight: Kirigami.Units.gridUnit * 16

        ColumnLayout {
            anchors.fill: parent

            ListView {
                id: commandListView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: page.commands
                spacing: Kirigami.Units.smallSpacing

                delegate: Kirigami.AbstractCard {
                    width: commandListView.width

                    contentItem: RowLayout {
                        QQC2.CheckBox {
                            checked: modelData.enabled
                            onToggled: {
                                page.commands[index].enabled = checked;
                                page.persist();
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            QQC2.Label {
                                text: modelData.name || "(unnamed)"
                                font.bold: true
                            }
                            QQC2.Label {
                                text: modelData.command
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                                opacity: 0.7
                            }
                            QQC2.Label {
                                text: "every " + Math.round(modelData.intervalMs / 1000) + "s"
                                opacity: 0.6
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                            }
                        }

                        QQC2.ToolButton {
                            icon.name: "document-edit"
                            onClicked: editDialog.openFor(index)
                        }
                        QQC2.ToolButton {
                            icon.name: "edit-delete"
                            onClicked: {
                                page.commands.splice(index, 1);
                                page.persist();
                            }
                        }
                    }
                }
            }

            QQC2.Button {
                text: "Add command"
                icon.name: "list-add"
                Layout.alignment: Qt.AlignLeft
                onClicked: {
                    page.commands.push(CommandsJs.createDefaultEntry());
                    page.persist();
                    editDialog.openFor(page.commands.length - 1);
                }
            }
        }
    }

    QQC2.Dialog {
        id: editDialog
        title: "Edit command"
        modal: true
        standardButtons: QQC2.Dialog.Save | QQC2.Dialog.Cancel
        width: Math.min(page.width - Kirigami.Units.gridUnit * 2, Kirigami.Units.gridUnit * 30)
        x: (page.width - width) / 2
        y: Kirigami.Units.gridUnit * 2

        property int index: -1
        property var colorRules: []

        function openFor(i) {
            index = i;
            var cmd = page.commands[i];
            nameField.text = cmd.name;
            commandField.text = cmd.command;
            intervalField.value = Math.round(cmd.intervalMs / 1000);
            colorRules = cmd.colorRules ? cmd.colorRules.map(function (r) { return { pattern: r.pattern, color: r.color }; }) : [];
            open();
        }

        onAccepted: {
            var cmd = page.commands[index];
            cmd.name = nameField.text;
            cmd.command = commandField.text;
            cmd.intervalMs = CommandsJs.clampInterval(intervalField.value * 1000);
            cmd.colorRules = colorRules.filter(function (r) { return r.pattern; });
            page.persist();
        }

        ColumnLayout {
            width: editDialog.width - Kirigami.Units.largeSpacing * 2

            Kirigami.FormLayout {
                Layout.fillWidth: true

                QQC2.TextField {
                    id: nameField
                    Kirigami.FormData.label: "Name:"
                    Layout.fillWidth: true
                }
                QQC2.TextArea {
                    id: commandField
                    Kirigami.FormData.label: "Command:"
                    Layout.fillWidth: true
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 3
                    wrapMode: TextEdit.Wrap
                }
                RowLayout {
                    Kirigami.FormData.label: "Interval:"
                    QQC2.SpinBox {
                        id: intervalField
                        from: 1
                        to: 86400
                        value: 5
                        editable: true
                    }
                    QQC2.Label {
                        text: "seconds (1 - 86400, i.e. up to 24h)"
                        opacity: 0.7
                    }
                }
            }

            Kirigami.Separator {
                Layout.fillWidth: true
            }

            QQC2.Label {
                text: "Color rules (plain-text, applied per line, in addition to any ANSI colors the command already emits):"
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }

            Repeater {
                model: editDialog.colorRules
                delegate: RowLayout {
                    Layout.fillWidth: true
                    QQC2.TextField {
                        Layout.fillWidth: true
                        placeholderText: "regex pattern, e.g. ERROR"
                        text: modelData.pattern
                        onEditingFinished: editDialog.colorRules[index].pattern = text
                    }
                    QQC2.TextField {
                        placeholderText: "#ff5555"
                        text: modelData.color
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 6
                        onEditingFinished: editDialog.colorRules[index].color = text
                    }
                    QQC2.ToolButton {
                        icon.name: "edit-delete"
                        onClicked: editDialog.colorRules.splice(index, 1)
                    }
                }
            }

            QQC2.Button {
                text: "Add color rule"
                icon.name: "list-add"
                Layout.alignment: Qt.AlignLeft
                onClicked: editDialog.colorRules.push({ pattern: "", color: "#ff5555" })
            }
        }
    }
}
