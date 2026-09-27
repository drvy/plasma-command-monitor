import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

Item {
    id: fullRep

    property var commandList: []
    property var outputMap: ({})

    property var runCommandFn
    property var copyFn
    property var isVisibleFn

    signal refreshRequested(var cmd)

    Layout.preferredWidth: Kirigami.Units.gridUnit * 22
    Layout.preferredHeight: Kirigami.Units.gridUnit * 20
    Layout.minimumWidth: Kirigami.Units.gridUnit * 14
    Layout.minimumHeight: Kirigami.Units.gridUnit * 10

    PlasmaComponents3.ScrollView {
        anchors.fill: parent

        ListView {
            id: listView
            model: fullRep.commandList
            spacing: Kirigami.Units.smallSpacing

            delegate: CommandDelegate {
                width: listView.width
                visible: fullRep.isVisibleFn ? fullRep.isVisibleFn(modelData) : true
                height: visible ? implicitHeight : 0
                command: modelData
                output: fullRep.outputMap[modelData.id]
                runCommandFn: fullRep.runCommandFn
                copyFn: fullRep.copyFn
                onRefreshRequested: function (cmd) {
                    fullRep.refreshRequested(cmd);
                }
            }

            PlasmaComponents3.Label {
                anchors.centerIn: parent
                visible: listView.count === 0
                text: "No commands configured yet. Right-click the widget and choose \"Configure...\" to add one."
                wrapMode: Text.Wrap
                width: parent.width - Kirigami.Units.largeSpacing * 2
                horizontalAlignment: Text.AlignHCenter
                opacity: 0.7
            }
        }
    }
}
