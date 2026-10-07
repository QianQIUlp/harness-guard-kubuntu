// The draft as it will load: policy and compiled-rule diff, then one password.
import QtQuick
import QtQuick.Controls.Basic as Q
import QtQuick.Layouts

Item {
    id: sheet
    property bool open: false
    signal closed()
    visible: open || panel.x < width
    readonly property bool applying: guard.applyExit === -2

    // Close once an apply succeeds, after a moment to read it.
    Connections {
        target: guard
        function onApplyChanged() { if (guard.applyExit === 0) done.restart() }
    }
    Timer { id: done; interval: 1600; onTriggered: sheet.closed() }

    Rectangle {
        anchors.fill: parent
        color: Theme.paper
        opacity: sheet.open ? 0.72 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.calm } }
        MouseArea { anchors.fill: parent; enabled: sheet.open; onClicked: if (!sheet.applying) sheet.closed() }
    }

    Rectangle {
        id: panel
        width: Math.min(640, parent.width - 260)
        height: parent.height
        x: sheet.open ? parent.width - width : parent.width
        color: Theme.raised
        Behavior on x { NumberAnimation { duration: Theme.calm; easing.type: Easing.OutCubic } }
        Rule { width: 1; height: parent.height }
        MouseArea { anchors.fill: parent }  // keep clicks inside

        ColumnLayout {
            anchors { fill: parent; margins: Theme.gutter }
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Caption { text: "Review · " + guard.changeCount + (guard.changeCount === 1 ? " change" : " changes") }
                Item { Layout.fillWidth: true }
                TextAction { glyph: "×"; text: "Close"; quiet: true; enabled: !sheet.applying; onClicked: sheet.closed() }
            }
            Text {
                Layout.topMargin: 22
                text: guard.applyExit === 0 ? "Applied." : guard.reviewOk ? "What will load." : "Not like this."
                color: guard.reviewOk || guard.applyExit === 0 ? Theme.ink : Theme.red
                font.family: Theme.sans
                font.pixelSize: 40
                font.weight: Font.Medium
                font.letterSpacing: -1.4
            }
            Text {
                Layout.topMargin: 8
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: guard.applyExit === 0 ? "Running agents have the new rules."
                    : guard.reviewOk ? "Path rules reach running agents within a second. The GitHub token waits for the next start."
                    : "The policy compiler refused the draft. Change it and review again."
                color: Theme.muted
                font.family: Theme.serif
                font.italic: true
                font.pixelSize: 14
            }

            ListView {
                id: diff
                Layout.topMargin: 26
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: guard.review.filter(l => !l.text.startsWith("+++"))
                boundsBehavior: Flickable.StopAtBounds
                Q.ScrollBar.vertical: Q.ScrollBar {}
                delegate: Rectangle {
                    id: line
                    required property var modelData
                    width: diff.width
                    height: text.implicitHeight + (modelData.kind === "h" ? 14 : 4)
                    color: modelData.kind === "+" ? Theme.faint : modelData.kind === "-" ? Theme.redWash : "transparent"
                    Text {
                        id: text
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 8; bottomMargin: 2 }
                        text: line.modelData.kind === "h" ? line.modelData.text.replace(/^--- /, "").replace(/^rules\//, "rules · ") : line.modelData.text
                        textFormat: Text.PlainText
                        wrapMode: Text.WrapAnywhere
                        font.family: Theme.mono
                        font.pixelSize: line.modelData.kind === "h" ? 10 : 12
                        font.letterSpacing: line.modelData.kind === "h" ? 1.2 : 0
                        font.capitalization: line.modelData.kind === "h" ? Font.AllUppercase : Font.MixedCase
                        color: line.modelData.kind === "-" ? Theme.red
                             : line.modelData.kind === "h" || line.modelData.kind === "@" ? Theme.muted : Theme.ink
                    }
                }
            }

            Rule { Layout.fillWidth: true; Layout.topMargin: 18 }
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 22
                spacing: 20
                Text {
                    Layout.fillWidth: true
                    text: guard.applyExit > 0 ? guard.applyOutput : ""
                    color: Theme.red
                    font.family: Theme.mono
                    font.pixelSize: 12
                    wrapMode: Text.Wrap
                    maximumLineCount: 4
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                }
                RoundAction {
                    glyph: guard.applyExit === 0 ? "✓" : "→"
                    text: sheet.applying ? "Waiting for your password…" : "Apply"
                    note: "pkexec asks for the admin password"
                    enabled: guard.reviewOk && !sheet.applying && guard.applyExit !== 0
                    onClicked: guard.applyReview()
                }
            }
        }
    }
}
