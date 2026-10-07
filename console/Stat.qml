// A number set large with a caption under it.
import QtQuick

Column {
    id: stat
    property string value
    property string label
    property color color: Theme.ink
    spacing: 4
    Text {
        text: stat.value
        color: stat.color
        font.family: Theme.sans
        font.pixelSize: 40
        font.weight: Font.Medium
        font.letterSpacing: -1.5
        font.features: { "tnum": 1 }
        textFormat: Text.PlainText
    }
    Caption { text: stat.label }
}
