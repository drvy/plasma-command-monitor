// SPDX-FileCopyrightText: 2026 Dragomir Yordanov <dyordanov@drvy.net>
// SPDX-License-Identifier: MIT

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: delegate

    property var command
    property var output

    // Right-click menu entries: always both available, "Run" disabled if no click command.
    property var runCommandFn
    property var copyFn

    signal refreshRequested(var cmd)

    Layout.fillWidth: true
    spacing: Kirigami.Units.smallSpacing

    RowLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            visible: !!delegate.command.icon
            source: delegate.command.icon
            color: delegate.command.labelColor || Kirigami.Theme.textColor
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
            Layout.alignment: Qt.AlignTop
        }

        PlasmaComponents3.Label {
            text: delegate.command.name
            color: delegate.command.labelColor || Kirigami.Theme.textColor
            font.bold: delegate.command.labelBold !== false
            font.italic: !!delegate.command.labelItalic
            Layout.alignment: Qt.AlignTop
        }

        PlasmaComponents3.Label {
            Layout.fillWidth: true
            textFormat: Text.RichText
            wrapMode: Text.Wrap
            font.family: "monospace"
            font.bold: !!delegate.command.outputBold
            font.italic: !!delegate.command.outputItalic
            opacity: delegate.output && delegate.output.richHtml ? 1 : 0.5
            text: (delegate.output && delegate.output.richHtml) || i18n("(no output)")

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.RightButton
                onClicked: contextMenu.popup()
            }

            QQC2.Menu {
                id: contextMenu

                QQC2.MenuItem {
                    text: i18n("Run command")
                    enabled: !!delegate.command.clickCommand
                    onTriggered: if (delegate.runCommandFn) delegate.runCommandFn(delegate.command)
                }
                QQC2.MenuItem {
                    text: i18n("Copy to clipboard")
                    onTriggered: if (delegate.copyFn) delegate.copyFn(delegate.command)
                }
            }
        }

        PlasmaComponents3.ToolButton {
            icon.name: "view-refresh"
            display: PlasmaComponents3.AbstractButton.IconOnly
            PlasmaComponents3.ToolTip.text: i18n("Run now")
            PlasmaComponents3.ToolTip.visible: hovered
            onClicked: delegate.refreshRequested(delegate.command)
        }
    }

    PlasmaComponents3.Label {
        visible: delegate.output && delegate.output.stderr
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        font.family: "monospace"
        color: Kirigami.Theme.negativeTextColor
        text: delegate.output ? delegate.output.stderr : ""
    }

    Kirigami.Separator {
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.smallSpacing
    }
}
