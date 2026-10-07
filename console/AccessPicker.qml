// Access as letters: R, W, X, and a deny mark. W and X imply R; R off is deny.
import QtQuick
import QtQuick.Controls.Basic as Q

Row {
    id: picker
    property string access: "r"
    property int cell: 30
    signal picked(string access)
    spacing: 3

    function toggled(letter) {
        if (letter === "deny")
            return access === "none" ? "r" : "none"
        let r = access !== "none", w = access.indexOf("w") >= 0, x = access.indexOf("x") >= 0
        if (letter === "r") { if (r) return "none"; r = true }
        if (letter === "w") { w = !w; r = true }
        if (letter === "x") { x = !x; r = true }
        return "r" + (w ? "w" : "") + (x ? "x" : "")
    }

    Repeater {
        model: ["r", "w", "x", "deny"]
        Q.AbstractButton {
            id: cell
            required property string modelData
            readonly property bool deny: modelData === "deny"
            readonly property bool on: deny ? picker.access === "none"
                                            : picker.access !== "none" && picker.access.indexOf(modelData) >= 0
            width: picker.cell
            height: Math.round(picker.cell * 0.9)
            hoverEnabled: true
            focusPolicy: Qt.StrongFocus
            Accessible.name: ({ r: "Read", w: "Write", x: "Run", deny: "Deny" })[modelData]
            onClicked: picker.picked(picker.toggled(modelData))
            Q.ToolTip.visible: hovered
            Q.ToolTip.delay: 600
            Q.ToolTip.text: Accessible.name
            background: Rectangle {
                radius: 3
                color: cell.on ? (cell.deny ? Theme.red : Theme.ink) : "transparent"
                border.color: cell.visualFocus ? Theme.red : cell.hovered || cell.on ? "transparent" : Theme.faint
                border.width: 1
                Rectangle {
                    anchors.fill: parent
                    radius: 3
                    color: Theme.faint
                    visible: cell.hovered && !cell.on
                }
            }
            contentItem: Text {
                text: cell.deny ? "⊘" : cell.modelData.toUpperCase()
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                color: cell.on ? Theme.paper : Theme.muted
                font.family: Theme.mono
                font.pixelSize: picker.cell > 32 ? 13 : 12
                font.weight: cell.on ? Font.DemiBold : Font.Normal
            }
        }
    }
}
