// On/off as a short track; the knob turns red when on.
import QtQuick
import QtQuick.Controls.Basic as Q

Q.AbstractButton {
    id: control
    checkable: true
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    implicitWidth: 34 + (text ? 10 + label.implicitWidth : 0)
    implicitHeight: 24
    contentItem: Item {
        Rectangle {
            id: track
            width: 34
            height: 16
            radius: 8
            anchors.verticalCenter: parent.verticalCenter
            color: "transparent"
            border.color: control.checked ? Theme.red : Theme.line
            border.width: control.visualFocus ? 2 : 1
            Rectangle {
                width: 10
                height: 10
                radius: 5
                y: 3
                x: control.checked ? parent.width - width - 3 : 3
                color: control.checked ? Theme.red : Theme.muted
                Behavior on x { NumberAnimation { duration: Theme.quick; easing.type: Easing.OutCubic } }
            }
        }
        Text {
            id: label
            visible: control.text !== ""
            anchors.left: track.right
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: control.text
            color: Theme.ink
            font.family: Theme.sans
            font.pixelSize: 13
            textFormat: Text.PlainText
        }
    }
    background: null
}
