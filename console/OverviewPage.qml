// One sentence for the whole machine, then each agent as a field coloured by its
// state: red open, ink running, paper idle. The eye goes red, then ink, then the rest.
import QtQuick
import QtQuick.Controls.Basic as Q
import QtQuick.Layouts

Item {
    id: page
    property var nav
    readonly property var words: ["No", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight"]
    readonly property int open: guard.agents.filter(a => !nav.held(a)).length
    readonly property int live: guard.agents.filter(a => (guard.running[a.id] || 0) > 0).length
    readonly property int denied: guard.denialHours.reduce((n, b) => n + b.total, 0)

    function word(n) { return n < words.length ? words[n] : String(n) }

    // The site's solid/outline pair: the sentence in ink, the count as a hollow giant.
    OutlineText {
        anchors { right: parent.right; top: parent.top; rightMargin: -40; topMargin: -170 }
        text: String(guard.agents.length)
        font.family: Theme.sans
        font.weight: Font.Bold
        font.pixelSize: 520
        color: page.open ? Theme.red : Qt.alpha(Theme.ink, 0.16)
        stroke: 1.2
        rotation: 6
        draw: true
    }

    Flickable {
        anchors.fill: parent
        contentHeight: column.implicitHeight + 2 * Theme.gutter
        boundsBehavior: Flickable.StopAtBounds
        Q.ScrollBar.vertical: Q.ScrollBar {}

        ColumnLayout {
            id: column
            x: Theme.gutter
            y: Theme.gutter
            width: parent.width - 2 * Theme.gutter
            spacing: 0

            Caption { text: "Overview · " + Qt.formatDate(new Date(), "dddd d MMMM") }

            // Generated only from counts, so styled text is safe here.
            Text {
                Layout.topMargin: 22
                Layout.fillWidth: true
                textFormat: Text.StyledText
                color: Theme.ink
                font.family: Theme.sans
                font.pixelSize: 60
                font.weight: Font.Medium
                font.letterSpacing: -2.2
                lineHeight: 1.0
                wrapMode: Text.WordWrap
                text: page.word(guard.agents.length) + " agents,<br>"
                      + "<font face='" + Theme.serif + "' color='" + (page.open ? Theme.red : Theme.ink) + "'><i>"
                      + (page.open === 0 ? "all held." : page.word(page.open).toLowerCase() + " left open.")
                      + "</i></font>"
            }

            Flow {
                Layout.topMargin: 22
                Layout.fillWidth: true
                spacing: 30
                TextAction {
                    quiet: true
                    glyph: page.live ? "●" : "○"
                    text: page.live === 0 ? "Nothing running" : page.word(page.live) + " running"
                    onClicked: {}
                    enabled: false
                    opacity: 1
                }
                TextAction {
                    quiet: guard.checkExit <= 0
                    text: guard.checkExit === -2 ? "Checking the machine…"
                        : guard.checkExit === 0 ? "Every check passed at " + guard.checkTime
                        : guard.checkExit > 0 ? "Some checks failed at " + guard.checkTime : "Not checked yet"
                    glyph: guard.checkExit > 0 ? "▲" : "✓"
                    accent: guard.checkExit > 0
                    onClicked: page.nav.open("integrity")
                }
                TextAction {
                    quiet: true
                    glyph: "↯"
                    text: page.denied === 1 ? "1 refusal in 24 hours" : page.denied + " refusals in 24 hours"
                    onClicked: page.nav.open("activity")
                }
            }

            GridLayout {
                id: grid
                Layout.topMargin: 40
                Layout.fillWidth: true
                columns: width > 760 ? 2 : 1
                columnSpacing: 14
                rowSpacing: 14

                Repeater {
                    model: guard.agents
                    Q.AbstractButton {
                        id: cell
                        required property var modelData
                        required property int index
                        readonly property int procs: guard.running[modelData.id] || 0
                        readonly property string st: Theme.stateOf(modelData, procs)
                        readonly property color fore: Theme.fore(st)
                        readonly property var paths: (guard.draft[modelData.id] || {}).paths || []
                        readonly property int refused: guard.denialCounts[modelData.id] || 0
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        implicitHeight: 236
                        hoverEnabled: true
                        focusPolicy: Qt.StrongFocus
                        onClicked: page.nav.open("agent", modelData.id)
                        scale: down ? 0.99 : 1
                        Behavior on scale { NumberAnimation { duration: Theme.quick } }

                        background: Rectangle {
                            color: Theme.fill(cell.st)
                            border.color: cell.st === "idle" ? (cell.hovered ? Theme.ink : Theme.line) : "transparent"
                            border.width: cell.visualFocus ? 2 : 1
                            Behavior on color { ColorAnimation { duration: Theme.calm } }
                            Behavior on border.color { ColorAnimation { duration: Theme.quick } }
                            Rectangle {
                                anchors.fill: parent
                                color: cell.fore
                                opacity: cell.hovered && cell.st !== "idle" ? 0.06 : 0
                                Behavior on opacity { NumberAnimation { duration: Theme.quick } }
                            }
                            Pulse {
                                anchors { left: parent.horizontalCenter; right: parent.right; bottom: parent.bottom; margins: 1; leftMargin: 20 }
                                height: 52
                                samples: (guard.pulse[cell.modelData.id] || []).slice(-36)
                                color: cell.fore
                                opacity: cell.st === "running" ? 0.4 : 0
                            }
                        }

                        contentItem: Item {
                            RowLayout {
                                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 26 }
                                spacing: 9
                                StateMark { state: cell.st; tint: cell.fore }
                                Text {
                                    text: cell.st === "open" ? "OPEN" : cell.st === "running" ? "RUNNING" : "IDLE"
                                    color: cell.fore
                                    font.family: Theme.mono
                                    font.pixelSize: 11
                                    font.letterSpacing: 2
                                    font.weight: Font.DemiBold
                                }
                                Caption {
                                    Layout.fillWidth: true
                                    color: Theme.soft(cell.st)
                                    text: cell.st === "running" ? "· " + cell.procs + (cell.procs === 1 ? " process" : " processes") : ""
                                }
                                Caption {
                                    color: Theme.soft(cell.st)
                                    text: cell.modelData.version ? "v" + cell.modelData.version : ""
                                }
                            }
                            AgentName {
                                x: 26 + (cell.hovered ? 4 : 0)
                                y: 66
                                width: parent.width - 52 - (quick.visible ? quick.width : 0)
                                text: cell.modelData.name
                                held: cell.st !== "open"
                                size: 46
                                color: cell.fore
                                outline: Theme.bright
                                Behavior on x { NumberAnimation { duration: Theme.calm; easing.type: Easing.OutCubic } }
                            }
                            Text {
                                x: 26
                                y: 128
                                width: parent.width - 52
                                text: cell.st === "open"
                                      ? (!cell.modelData.guarded ? "Its entry point no longer runs the launcher." : "Its profile is not enforcing.")
                                      : cell.paths.map(p => p.path + " " + (p.access === "none" ? "⊘" : p.access.toUpperCase())).join("   ")
                                color: cell.st === "open" ? cell.fore : Theme.soft(cell.st)
                                font.family: cell.st === "open" ? Theme.serif : Theme.mono
                                font.italic: cell.st === "open"
                                font.pixelSize: cell.st === "open" ? 15 : 12
                                elide: Text.ElideRight
                                textFormat: Text.PlainText
                            }
                            Row {
                                x: 26
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 24
                                spacing: 24
                                Caption {
                                    color: cell.fore
                                    text: cell.paths.filter(p => p.access !== "none").length + " places"
                                }
                                Caption {
                                    color: cell.refused ? cell.fore : Theme.soft(cell.st)
                                    text: cell.refused === 1 ? "1 refusal" : cell.refused + " refusals"
                                }
                                Rectangle {
                                    visible: !!guard.changes[cell.modelData.id]
                                    width: edited.implicitWidth + 12
                                    height: 17
                                    radius: 2
                                    color: cell.st === "idle" ? Theme.red : cell.fore
                                    Caption {
                                        id: edited
                                        anchors.centerIn: parent
                                        color: cell.st === "idle" ? Theme.bright : Theme.fill(cell.st)
                                        text: "Edited"
                                    }
                                }
                            }
                            // Idle and held: start it from here.
                            RoundAction {
                                id: quick
                                anchors { right: parent.right; bottom: parent.bottom; margins: 22 }
                                visible: cell.st === "idle"
                                opacity: cell.hovered || visualFocus ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: Theme.quick } }
                                size: 44
                                glyph: "▶"
                                text: ""
                                Accessible.name: "Start " + cell.modelData.name
                                onClicked: guard.launch(cell.modelData.id, guard.folderFor(cell.modelData.id))
                            }
                        }
                    }
                }
            }

            // The last day across all agents.
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 48
                Text {
                    text: "Refusals, last 24 hours"
                    color: Theme.ink
                    font.family: Theme.sans
                    font.pixelSize: 15
                    font.weight: Font.Medium
                }
                Item { Layout.fillWidth: true }
                TextAction { quiet: true; glyph: "→"; text: "Activity"; onClicked: page.nav.open("activity") }
            }
            Bars {
                Layout.fillWidth: true
                Layout.topMargin: 14
                implicitHeight: 76
                buckets: guard.denialHours
            }
        }
    }
}
