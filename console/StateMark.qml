// An agent's state as a small square: red filled when open, ink filled (breathing)
// while running, an ink outline when idle. Squares are agents; round dots are checks.
import QtQuick

Rectangle {
    id: mark
    property string state: "idle"
    property color tint: state === "open" ? Theme.red : Theme.ink
    implicitWidth: 10
    implicitHeight: 10
    radius: 2
    color: state === "idle" ? "transparent" : tint
    border.width: state === "idle" ? 1.2 : 0
    border.color: tint
    Behavior on color { ColorAnimation { duration: Theme.calm } }

    Rectangle {
        anchors.centerIn: parent
        width: parent.width
        height: width
        radius: 2
        color: "transparent"
        border.color: mark.tint
        visible: mark.state !== "idle"
        SequentialAnimation on scale {
            running: mark.state !== "idle"
            loops: Animation.Infinite
            NumberAnimation { from: 1; to: 2.4; duration: mark.state === "open" ? 900 : 1800; easing.type: Easing.OutCubic }
            PauseAnimation { duration: 500 }
        }
        SequentialAnimation on opacity {
            running: mark.state !== "idle"
            loops: Animation.Infinite
            NumberAnimation { from: 0.8; to: 0; duration: mark.state === "open" ? 900 : 1800; easing.type: Easing.OutCubic }
            PauseAnimation { duration: 500 }
        }
    }
}
