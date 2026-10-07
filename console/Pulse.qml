// Running processes over the last three minutes as thin bars, newest on the right.
// Scaled to its own peak, so a quiet agent and a busy app both show their rhythm.
import QtQuick

Item {
    id: pulse
    property var samples: []
    property color color: Theme.ink
    readonly property int peak: Math.max(1, ...samples)
    implicitHeight: 48

    Row {
        anchors.fill: parent
        spacing: 2
        Repeater {
            model: pulse.samples
            Item {
                required property int modelData
                required property int index
                width: (pulse.width - (pulse.samples.length - 1) * 2) / Math.max(1, pulse.samples.length)
                height: pulse.height
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: parent.modelData ? Math.max(3, pulse.height * parent.modelData / pulse.peak) : 1
                    color: pulse.color
                    opacity: parent.modelData ? 0.35 + 0.65 * parent.index / pulse.samples.length : 0.3
                    Behavior on height { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
                }
            }
        }
    }
}
