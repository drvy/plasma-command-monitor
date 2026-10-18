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
            Kirigami.FormData.label: "Compact icon:"
            text: page.cfg_compactIcon
            placeholderText: "utilities-terminal"
            onEditingFinished: page.cfg_compactIcon = text
            Layout.preferredWidth: Kirigami.Units.gridUnit * 14
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Commands"
        }

        RowLayout {
            Kirigami.FormData.label: " "
            QQC2.Button {
                text: "Add command"
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
            text: "No commands yet. Click \"Add command\" to run your first one."
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
                            QQC2.ToolTip.text: "Move up"
                            QQC2.ToolTip.visible: hovered
                            onClicked: page.moveCommand(index, index - 1)
                        }
                        QQC2.ToolButton {
                            icon.name: "arrow-down"
                            enabled: index < page.commands.length - 1
                            QQC2.ToolTip.text: "Move down"
                            QQC2.ToolTip.visible: hovered
                            onClicked: page.moveCommand(index, index + 1)
                        }
                    }

                    QQC2.CheckBox {
                        checked: modelData.enabled
                        QQC2.ToolTip.text: "Enabled"
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
                        QQC2.ToolTip.text: "Show this command's output in the panel"
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
                            text: modelData.name || "(unnamed)"
                            color: modelData.labelColor || Kirigami.Theme.textColor
                            font.bold: true
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                        QQC2.Label {
                            text: modelData.command || "(no command set)"
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
                        QQC2.ToolTip.text: "Edit"
                        QQC2.ToolTip.visible: hovered
                        onClicked: editDialog.openFor(index)
                    }
                    QQC2.ToolButton {
                        icon.name: "edit-delete"
                        QQC2.ToolTip.text: "Delete"
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
        title: "Edit command"

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
                text: "Cancel"
                onClicked: editDialog.close()
            }
            Item {
                Layout.fillWidth: true
            }
            QQC2.Button {
                text: "Save"
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
                QQC2.SpinBox {
                    id: intervalField
                    Kirigami.FormData.label: "Interval (seconds):"
                    from: 1
                    to: 86400
                    value: 5
                    editable: true
                }

                RowLayout {
                    Kirigami.FormData.label: "Icon:"
                    Kirigami.Icon {
                        source: iconField.text || "unknown"
                        color: labelColorField.text || Kirigami.Theme.textColor
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: Kirigami.Units.iconSizes.small
                    }
                    QQC2.TextField {
                        id: iconField
                        placeholderText: "icon name, e.g. utilities-terminal"
                        Layout.fillWidth: true
                    }
                    QQC2.Button {
                        icon.name: "list-add"
                        text: "Choose..."
                        onClicked: iconDialog.open()
                    }
                }
                QQC2.TextField {
                    id: labelColorField
                    Kirigami.FormData.label: "Color:"
                    placeholderText: "#e5c07b (used for both the icon and the name)"
                    Layout.fillWidth: true
                }
                RowLayout {
                    Kirigami.FormData.label: "Name style:"
                    QQC2.CheckBox {
                        id: labelBoldField
                        text: "Bold"
                    }
                    QQC2.CheckBox {
                        id: labelItalicField
                        text: "Italic"
                    }
                }
                RowLayout {
                    Kirigami.FormData.label: "Output style:"
                    QQC2.CheckBox {
                        id: outputBoldField
                        text: "Bold"
                    }
                    QQC2.CheckBox {
                        id: outputItalicField
                        text: "Italic"
                    }
                }
                QQC2.TextField {
                    id: clickCommandField
                    Kirigami.FormData.label: "Click command:"
                    placeholderText: "run on click, e.g. notify-send hello"
                    Layout.fillWidth: true
                }
                QQC2.CheckBox {
                    id: hideWhenEmptyField
                    Kirigami.FormData.label: "Visibility:"
                    text: "Hide this command entirely when its output is empty"
                }
            }

            QQC2.Label {
                text: "Left click runs the click command above if set, otherwise copies the output. Right click always shows the normal widget menu (Configure...), with \"Run command\" / \"Copy to clipboard\" for whichever command you're hovering added in."
                wrapMode: Text.Wrap
                opacity: 0.6
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                Layout.fillWidth: true
            }

            QQC2.Label {
                text: "1 to 86400 seconds (24h)"
                opacity: 0.6
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                Layout.fillWidth: true
            }

            Kirigami.Separator {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
            }

            QQC2.Label {
                text: "Color rules (plain-text, applied per line, on top of any ANSI colors the command already emits):"
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
