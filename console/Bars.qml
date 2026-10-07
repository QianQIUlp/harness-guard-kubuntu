// Counts over time as bars, with a hairline floor; hover a bar for its value.
// `buckets` are {t, total, agents}; `agent` limits them to one agent.
import QtQuick
import QtQuick.Controls.Basic as Q

Item {
    id: bars
    property var buckets: []
    property string agent: ""
    property string format: "HH:00"
    property color color: Theme.ink
    property bool labels: true
    readonly property var values: buckets.map(b => agent === "" ? b.total : (b.agents[agent] || 0))
    readonly property int peak: Math.max(1, ...values)
    implicitHeight: 96

    Rule { id: floor; width: parent.width; anchors.bottom: parent.bottom; anchors.bottomMargin: bars.labels ? 18 : 0 }
    Row {
        anchors { left: parent.left; right: parent.right; top: parent.top; bottom: floor.top }
        spacing: 3
        Repeater {
            model: bars.values.length
            Item {
                id: bar
                required property int index
                readonly property int value: bars.values[index]
                width: (bars.width - (bars.values.length - 1) * 3) / Math.max(1, bars.values.length)
                height: parent.height
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: bar.value ? Math.max(2, (parent.height - 4) * bar.value / bars.peak) : 0
                    color: bars.color
                    opacity: hover.containsMouse ? 1 : bar.index === bars.values.length - 1 ? 0.9 : 0.42
                    Behavior on height { NumberAnimation { duration: Theme.calm; easing.type: Easing.OutCubic } }
                }
                MouseArea { id: hover; anchors.fill: parent; hoverEnabled: true }
                Q.ToolTip.visible: hover.containsMouse
                Q.ToolTip.text: Qt.formatDateTime(new Date(bars.buckets[index].t * 1000), bars.format === "HH:00" ? "ddd HH:00" : "ddd d MMM")
                                + " · " + bar.value + (bar.value === 1 ? " refusal" : " refusals")
            }
        }
    }
    Repeater {
        model: bars.labels ? [0, Math.floor(bars.values.length / 2), bars.values.length - 1] : []
        Caption {
            required property int modelData
            visible: bars.buckets.length > modelData
            y: bars.height - 12
            x: modelData === 0 ? 0 : modelData === bars.values.length - 1 ? bars.width - width
               : bars.width * modelData / bars.values.length - width / 2
            text: bars.buckets.length > modelData ? Qt.formatDateTime(new Date(bars.buckets[modelData].t * 1000), bars.format) : ""
        }
    }
}
