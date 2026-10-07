// Status dot: filled ink when fine, red when not; breathes while `live`.
import QtQuick

Rectangle {
    id: dot
    property bool good: true
    property bool live: false
    property bool hollow: false
    implicitWidth: 8
    implicitHeight: 8
    radius: width / 2
    color: hollow ? "transparent" : good ? Theme.ink : Theme.red
    border.width: hollow ? 1 : 0
    border.color: good ? Theme.ink : Theme.red

    Rectangle {
        anchors.centerIn: parent
        width: parent.width
        height: width
        radius: width / 2
        color: "transparent"
        border.color: Theme.red
        border.width: 1
        visible: dot.live
        SequentialAnimation on scale {
            running: dot.live
            loops: Animation.Infinite
            NumberAnimation { from: 1; to: 2.6; duration: 1600; easing.type: Easing.OutCubic }
            PauseAnimation { duration: 600 }
        }
        SequentialAnimation on opacity {
            running: dot.live
            loops: Animation.Infinite
            NumberAnimation { from: 0.9; to: 0; duration: 1600; easing.type: Easing.OutCubic }
            PauseAnimation { duration: 600 }
        }
    }
}
