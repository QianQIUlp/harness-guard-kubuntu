// Text drawn as a hairline stroke, never filled: the site's outlined 秋.
// `draw` animates the stroke in once (ShapePath.trim, Qt 6.10).
import QtQuick
import QtQuick.Shapes

Shape {
    id: outline
    property string text
    property alias font: metrics.font
    property color color: Theme.line
    property real stroke: 1
    property bool draw: false
    property real progress: draw ? 0 : 1
    implicitWidth: metrics.advanceWidth(text) + stroke * 2
    implicitHeight: metrics.height
    preferredRendererType: Shape.CurveRenderer

    FontMetrics { id: metrics }
    // PathText puts the glyphs' bounding box at (x, y), not the baseline (Qt 6.10),
    // so offset by the tight box to line up with a Text of the same font.
    readonly property rect tight: { metrics.font; return metrics.tightBoundingRect(text) }
    NumberAnimation on progress {
        running: outline.draw
        from: 0
        to: 1
        duration: 1800
        easing.type: Easing.InOutCubic
    }

    ShapePath {
        strokeColor: outline.color
        strokeWidth: outline.stroke
        fillColor: "transparent"
        fillRule: ShapePath.WindingFill
        joinStyle: ShapePath.RoundJoin
        trim.end: outline.progress
        PathText {
            x: outline.stroke + outline.tight.x
            y: metrics.ascent + outline.tight.y
            font: metrics.font
            text: outline.text
        }
    }
}
