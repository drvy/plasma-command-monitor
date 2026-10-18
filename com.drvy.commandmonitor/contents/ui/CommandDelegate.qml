import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: delegate

    property var command
    property var output

    signal refreshRequested(var cmd)

    Layout.fillWidth: true
    spacing: Kirigami.Units.smallSpacing

    RowLayout {
        Layout.fillWidth: true

        PlasmaComponents3.Label {
            text: delegate.command.name || delegate.command.command
            font.bold: true
            Layout.fillWidth: true
            elide: Text.ElideRight
        }

        PlasmaComponents3.Label {
            visible: delegate.output && delegate.output.exitCode !== undefined && delegate.output.exitCode !== 0
            text: "exit " + (delegate.output ? delegate.output.exitCode : "")
            color: Kirigami.Theme.negativeTextColor
        }

        PlasmaComponents3.ToolButton {
            icon.name: "view-refresh"
            display: PlasmaComponents3.AbstractButton.IconOnly
            PlasmaComponents3.ToolTip.text: "Run now"
            PlasmaComponents3.ToolTip.visible: hovered
            onClicked: delegate.refreshRequested(delegate.command)
        }
    }

    PlasmaComponents3.Label {
        Layout.fillWidth: true
        textFormat: Text.RichText
        wrapMode: Text.Wrap
        font.family: "monospace"
        text: delegate.output ? delegate.output.richHtml : ""
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
