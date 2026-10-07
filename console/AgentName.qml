// An agent's name set large: solid ink when it is held, a red hairline outline when
// it isn't, so an open guard reads as hollow before any word is read.
import QtQuick

Item {
    id: name
    property string text
    property bool held: true
    property int size: 44
    property real tracking: -1.2
    property color color: Theme.ink
    property color outline: Theme.red
    implicitWidth: solid.implicitWidth
    implicitHeight: solid.implicitHeight

    Text {
        id: solid
        width: parent.width
        visible: name.held
        text: name.text
        color: name.color
        font.family: Theme.sans
        font.weight: Font.Bold
        font.pixelSize: name.size
        font.letterSpacing: name.tracking
        elide: Text.ElideRight
        textFormat: Text.PlainText
    }
    OutlineText {
        visible: !name.held
        text: name.text
        font: solid.font
        color: name.outline
        stroke: Math.max(1, name.size / 40)
    }
}
