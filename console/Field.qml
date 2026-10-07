// Text input drawn as a single hairline, mono like the paths it holds.
import QtQuick
import QtQuick.Controls.Basic as Q

Q.TextField {
    id: control
    property color lineColor: Theme.line
    property color focusColor: Theme.red
    color: Theme.ink
    placeholderTextColor: Theme.muted
    selectionColor: Theme.redWash
    selectedTextColor: Theme.ink
    font.family: Theme.mono
    font.pixelSize: 13
    leftPadding: 0
    rightPadding: 0
    topPadding: 8
    bottomPadding: 8
    background: Rectangle {
        color: "transparent"
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: control.activeFocus ? 2 : 1
            color: control.activeFocus ? control.focusColor : control.lineColor
        }
    }
}
