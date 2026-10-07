// A text button: ink label, hairline underline that darkens on hover, optional glyph.
import QtQuick
import QtQuick.Controls.Basic as Q

Q.AbstractButton {
    id: control
    property string glyph: ""
    property bool accent: false
    property bool quiet: false
    property bool current: false
    property color labelColor: control.accent ? Theme.red : control.quiet && !control.hovered ? Theme.muted : Theme.ink
    implicitWidth: row.implicitWidth
    implicitHeight: Math.max(28, row.implicitHeight + 8)
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    opacity: enabled ? 1 : 0.35

    contentItem: Item {
        Row {
            id: row
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Text {
                visible: control.glyph !== ""
                text: control.glyph
                color: control.accent || control.current ? Theme.red : control.labelColor
                font.family: Theme.sans
                font.pixelSize: 14
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                id: label
                text: control.text
                color: control.labelColor
                font.family: Theme.sans
                font.pixelSize: 13
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
            }
        }
        Rectangle {
            anchors.left: row.left
            anchors.leftMargin: control.glyph !== "" ? row.children[0].width + 8 : 0
            anchors.top: row.bottom
            anchors.topMargin: 2
            height: 1
            width: label.width
            color: control.labelColor
            opacity: control.hovered || control.visualFocus ? 1 : control.quiet ? 0 : 0.25
            Behavior on opacity { NumberAnimation { duration: Theme.quick } }
        }
    }
    background: null
}
