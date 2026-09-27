// SPDX-FileCopyrightText: 2026 Dragomir Yordanov <dyordanov@drvy.net>
// SPDX-License-Identifier: MIT

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.iconthemes as KIconThemes
import "../code/commands.js" as CommandsJs

KCM.SimpleKCM {
    id: page

    // Bound by the Plasma config system to the kcfg entries in main.xml.
    property string cfg_commandsJson: "[]"
    property string cfg_compactIcon: "utilities-terminal"

    property var commands: []

    function reloadFromCfg() {
        commands = CommandsJs.parseCommands(cfg_commandsJson);
    }

    function persist() {
        cfg_commandsJson = CommandsJs.serializeCommands(commands);
        var snapshot = commands;
        commands = [];
        commands = snapshot;
    }

    // Display order (panel segments and popup rows both follow this array's
    // order), so moving a command here is how the user picks what shows
    // first, second, etc.
    function moveCommand(from, to) {
        if (to < 0 || to >= commands.length) {
            return;
        }
        var item = commands[from];
        commands.splice(from, 1);
        commands.splice(to, 0, item);
        persist();
    }

    Component.onCompleted: reloadFromCfg()

    // KCM.SimpleKCM (a Kirigami.ScrollablePage) expects a single content
    // item; everything below is nested inside this one ColumnLayout so the
    // form and the command list stack instead of overlapping at (0, 0).
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

    Kirigami.FormLayout {
        Layout.fillWidth: true

        QQC2.TextField {
            id: compactIconField
            Kirigami.FormData.label: i18n("Compact icon:")
            text: page.cfg_compactIcon
            placeholderText: "utilities-terminal"
            onEditingFinished: page.cfg_compactIcon = text
            Layout.preferredWidth: Kirigami.Units.gridUnit * 14
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Commands")
        }

        RowLayout {
            Kirigami.FormData.label: " "
            QQC2.Button {
                text: i18n("Add command")
                icon.name: "list-add"
                onClicked: {
                    page.commands.push(CommandsJs.createDefaultEntry());
                    page.persist();
                    editDialog.openFor(page.commands.length - 1);
                }
            }
        }

        QQC2.Label {
            Kirigami.FormData.isSection: true
            visible: page.commands.length === 0
            text: i18n("No commands yet. Click \"Add command\" to run your first one.")
            opacity: 0.7
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        Repeater {
            model: page.commands
            delegate: Kirigami.AbstractCard {
                Layout.fillWidth: true

                contentItem: RowLayout {
                    spacing: Kirigami.Units.smallSpacing

                    ColumnLayout {
                        spacing: 0
                        QQC2.ToolButton {
                            icon.name: "arrow-up"
                            enabled: index > 0
                            QQC2.ToolTip.text: i18n("Move up")
                            QQC2.ToolTip.visible: hovered
                            onClicked: page.moveCommand(index, index - 1)
                        }
                        QQC2.ToolButton {
                            icon.name: "arrow-down"
                            enabled: index < page.commands.length - 1
                            QQC2.ToolTip.text: i18n("Move down")
                            QQC2.ToolTip.visible: hovered
                            onClicked: page.moveCommand(index, index + 1)
                        }
                    }

                    QQC2.CheckBox {
                        checked: modelData.enabled
                        QQC2.ToolTip.text: i18n("Enabled")
                        QQC2.ToolTip.visible: hovered
                        onToggled: {
                            page.commands[index].enabled = checked;
                            page.persist();
                        }
                    }

                    QQC2.ToolButton {
                        icon.name: modelData.showInPanel !== false ? "visibility" : "hint"
                        checkable: true
                        checked: modelData.showInPanel !== false
                        QQC2.ToolTip.text: i18n("Show this command's output in the panel")
                        QQC2.ToolTip.visible: hovered
                        onToggled: {
                            page.commands[index].showInPanel = checked;
                            page.persist();
                        }
                    }

                    Kirigami.Icon {
                        visible: !!modelData.icon
                        source: modelData.icon
                        color: modelData.labelColor || Kirigami.Theme.textColor
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: Kirigami.Units.iconSizes.small
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        QQC2.Label {
                            text: modelData.name || i18n("(unnamed)")
                            color: modelData.labelColor || Kirigami.Theme.textColor
                            font.bold: true
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                        QQC2.Label {
                            text: modelData.command || i18n("(no command set)")
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            opacity: 0.7
                        }
                        QQC2.Label {
                            text: i18n("every %1s", Math.round(modelData.intervalMs / 1000))
                            opacity: 0.6
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                        }
                    }

                    QQC2.ToolButton {
                        icon.name: "document-edit"
                        QQC2.ToolTip.text: i18n("Edit")
                        QQC2.ToolTip.visible: hovered
                        onClicked: editDialog.openFor(index)
                    }
                    QQC2.ToolButton {
                        icon.name: "edit-delete"
                        QQC2.ToolTip.text: i18n("Delete")
                        QQC2.ToolTip.visible: hovered
                        onClicked: {
                            page.commands.splice(index, 1);
                            page.persist();
                        }
                    }
                }
            }
        }
    }
    } // end outer ColumnLayout

    Kirigami.OverlaySheet {
        id: editDialog
        title: i18n("Edit command")

        property int index: -1
        property var colorRules: []

        function openFor(i) {
            index = i;
            var cmd = page.commands[i];
            nameField.text = cmd.name;
            commandField.text = cmd.command;
            intervalField.value = Math.round(cmd.intervalMs / 1000);
            iconField.text = cmd.icon || "";
            labelColorField.text = cmd.labelColor || "";
            labelBoldField.checked = cmd.labelBold !== false;
            labelItalicField.checked = !!cmd.labelItalic;
            outputBoldField.checked = !!cmd.outputBold;
            outputItalicField.checked = !!cmd.outputItalic;
            clickCommandField.text = cmd.clickCommand || "";
            hideWhenEmptyField.checked = !!cmd.hideWhenEmpty;
            colorRules = cmd.colorRules ? cmd.colorRules.map(function (r) { return { pattern: r.pattern, color: r.color }; }) : [];
            open();
        }

        function save() {
            var cmd = page.commands[index];
            cmd.name = nameField.text;
            cmd.command = commandField.text;
            cmd.intervalMs = CommandsJs.clampInterval(intervalField.value * 1000);
            cmd.icon = iconField.text;
            cmd.labelColor = labelColorField.text;
            cmd.labelBold = labelBoldField.checked;
            cmd.labelItalic = labelItalicField.checked;
            cmd.outputBold = outputBoldField.checked;
            cmd.outputItalic = outputItalicField.checked;
            cmd.clickCommand = clickCommandField.text;
            cmd.hideWhenEmpty = hideWhenEmptyField.checked;
            cmd.colorRules = colorRules.filter(function (r) { return r.pattern; });
            page.persist();
            close();
        }

        footer: RowLayout {
            QQC2.Button {
                text: i18n("Cancel")
                onClicked: editDialog.close()
            }
            Item {
                Layout.fillWidth: true
            }
            QQC2.Button {
                text: i18n("Save")
                icon.name: "dialog-ok"
                onClicked: editDialog.save()
            }
        }

        KIconThemes.IconDialog {
            id: iconDialog
            onIconNameChanged: iconField.text = iconName
        }

        ColumnLayout {
            id: dialogContent
            Layout.preferredWidth: Kirigami.Units.gridUnit * 26
            spacing: Kirigami.Units.largeSpacing

            Kirigami.FormLayout {
                Layout.fillWidth: true

                QQC2.TextField {
                    id: nameField
                    Kirigami.FormData.label: i18n("Name:")
                    Layout.fillWidth: true
                }
                QQC2.TextArea {
                    id: commandField
                    Kirigami.FormData.label: i18n("Command:")
                    Layout.fillWidth: true
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 3
                    wrapMode: TextEdit.Wrap
                }
                QQC2.SpinBox {
                    id: intervalField
                    Kirigami.FormData.label: i18n("Interval (seconds):")
                    from: 1
                    to: 86400
                    value: 5
                    editable: true
                }

                RowLayout {
                    Kirigami.FormData.label: i18n("Icon:")
                    Kirigami.Icon {
                        source: iconField.text || "unknown"
                        color: labelColorField.text || Kirigami.Theme.textColor
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: Kirigami.Units.iconSizes.small
                    }
                    QQC2.TextField {
                        id: iconField
                        placeholderText: i18n("icon name, e.g. utilities-terminal")
                        Layout.fillWidth: true
                    }
                    QQC2.Button {
                        icon.name: "list-add"
                        text: i18n("Choose...")
                        onClicked: iconDialog.open()
                    }
                }
                QQC2.TextField {
                    id: labelColorField
                    Kirigami.FormData.label: i18n("Color:")
                    placeholderText: i18n("#e5c07b (used for both the icon and the name)")
                    Layout.fillWidth: true
                }
                RowLayout {
                    Kirigami.FormData.label: i18n("Name style:")
                    QQC2.CheckBox {
                        id: labelBoldField
                        text: i18n("Bold")
                    }
                    QQC2.CheckBox {
                        id: labelItalicField
                        text: i18n("Italic")
                    }
                }
                RowLayout {
                    Kirigami.FormData.label: i18n("Output style:")
                    QQC2.CheckBox {
                        id: outputBoldField
                        text: i18n("Bold")
                    }
                    QQC2.CheckBox {
                        id: outputItalicField
                        text: i18n("Italic")
                    }
                }
                QQC2.TextField {
                    id: clickCommandField
                    Kirigami.FormData.label: i18n("Click command:")
                    placeholderText: i18n("run on click, e.g. notify-send hello")
                    Layout.fillWidth: true
                }
                QQC2.CheckBox {
                    id: hideWhenEmptyField
                    Kirigami.FormData.label: i18n("Visibility:")
                    text: i18n("Hide this command entirely when its output is empty")
                }
            }

            QQC2.Label {
                text: i18n("Left click runs the click command above if set, otherwise copies the output. Right click always shows the normal widget menu (Configure...), with \"Run command\" / \"Copy to clipboard\" for whichever command you're hovering added in.")
                wrapMode: Text.Wrap
                opacity: 0.6
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                Layout.fillWidth: true
            }

            QQC2.Label {
                text: i18n("1 to 86400 seconds (24h)")
                opacity: 0.6
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                Layout.fillWidth: true
            }

            Kirigami.Separator {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
            }

            QQC2.Label {
                text: i18n("Color rules (plain-text, applied per line, on top of any ANSI colors the command already emits):")
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }

            Repeater {
                model: editDialog.colorRules
                delegate: RowLayout {
                    Layout.fillWidth: true
                    QQC2.TextField {
                        Layout.fillWidth: true
                        placeholderText: i18n("regex pattern, e.g. ERROR")
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
                text: i18n("Add color rule")
                icon.name: "list-add"
                Layout.alignment: Qt.AlignLeft
                onClicked: editDialog.colorRules.push({ pattern: "", color: "#ff5555" })
            }
        }
    }
}
