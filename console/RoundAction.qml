// The site's primary gesture: a red disc with a glyph, label and note beside it.
import QtQuick
import QtQuick.Controls.Basic as Q

Q.AbstractButton {
    id: control
    property string glyph: "→"
    property string note: ""
    property int size: 52
    property color disc: Theme.red
    property color glyphColor: "#fffdf7"
    property color labelColor: Theme.ink
    property color noteColor: Theme.muted
    property int labelSize: 14
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    implicitWidth: disc.width + 14 + Math.max(label.implicitWidth, noteText.implicitWidth)
    implicitHeight: disc.height
    opacity: enabled ? 1 : 0.4

    contentItem: Item {
        Rectangle {
            id: disc
            width: control.size
            height: control.size
            radius: control.size / 2
            color: control.disc
            scale: control.down ? 0.94 : control.hovered ? 1.05 : 1
            Behavior on scale { NumberAnimation { duration: Theme.quick; easing.type: Easing.OutCubic } }
            Text {
                anchors.centerIn: parent
                text: control.glyph
                color: control.glyphColor
                font.family: Theme.sans
                font.pixelSize: Math.round(control.size * 0.38)
            }
            Rectangle {
                anchors.centerIn: parent
                width: parent.width + 8
                height: width
                radius: width / 2
                color: "transparent"
                border.color: control.disc
                visible: control.visualFocus
            }
        }
        Column {
            anchors.left: disc.right
            anchors.leftMargin: 14
            anchors.verticalCenter: disc.verticalCenter
            spacing: 3
            Text {
                id: label
                text: control.text
                color: control.labelColor
                font.family: Theme.sans
                font.pixelSize: control.labelSize
                font.weight: Font.Medium
                textFormat: Text.PlainText
            }
            Text {
                id: noteText
                visible: text !== ""
                text: control.note
                color: control.noteColor
                font.family: Theme.sans
                font.pixelSize: 11
                textFormat: Text.PlainText
            }
        }
    }
    background: null
}
