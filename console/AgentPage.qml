// One agent. Its state is the colour of the whole hero (red open, ink running, paper
// idle) with the one action that matters there; then its numbers, reach and history.
import QtQuick
import QtQuick.Controls.Basic as Q
import QtQuick.Dialogs
import QtQuick.Layouts

Item {
    id: page
    property var nav
    property string agentId
    readonly property var agent: nav.agentById(agentId) || { name: agentId, profile: "", entry: "", guarded: true, enforcing: true }
    readonly property int procs: guard.running[agentId] || 0
    readonly property string st: Theme.stateOf(agent, procs)
    readonly property color fore: Theme.fore(st)
    readonly property var section: guard.draft[agentId] || { paths: [] }
    readonly property var change: guard.changes[agentId] || { changed: [], removed: [], token: false }
    readonly property var denials: guard.denials.filter(d => d.agent === agentId)
    readonly property var paths: section.paths || []
    readonly property int reach: paths.filter(p => p.access !== "none").length
    readonly property int writable: paths.filter(p => p.access.indexOf("w") >= 0).length
    readonly property int refusedDay: guard.denialHours.reduce((n, b) => n + (b.agents[agentId] || 0), 0)
    readonly property var log: guard.events.filter(e => e.agent === agentId).slice(0, 6)
    property string newAccess: "r"
    property bool confirmStop: false

    Timer { id: unconfirm; interval: 4000; onTriggered: page.confirmStop = false }

    component Heading: RowLayout {
        property string title
        property string note
        Layout.fillWidth: true
        Layout.topMargin: 64
        spacing: 18
        Text {
            text: parent.title
            color: Theme.ink
            font.family: Theme.sans
            font.pixelSize: 26
            font.weight: Font.Bold
            font.letterSpacing: -0.8
        }
        Text {
            Layout.fillWidth: true
            text: parent.note
            color: Theme.muted
            font.family: Theme.serif
            font.italic: true
            font.pixelSize: 14
            elide: Text.ElideRight
        }
    }

    Flickable {
        anchors.fill: parent
        contentHeight: column.implicitHeight + 2 * Theme.gutter
        boundsBehavior: Flickable.StopAtBounds
        Q.ScrollBar.vertical: Q.ScrollBar {}

        ColumnLayout {
            id: column
            x: Theme.gutter
            y: Theme.gutter - 8
            width: parent.width - 2 * Theme.gutter
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                TextAction { glyph: "←"; text: "Overview"; quiet: true; onClicked: page.nav.open("overview") }
                Item { Layout.fillWidth: true }
                Caption { text: page.agent.profile + " · " + (page.agent.version ? "v" + page.agent.version : "…") }
            }

            // The hero: the state as a field of colour.
            Rectangle {
                id: hero
                Layout.fillWidth: true
                Layout.topMargin: 18
                implicitHeight: 350
                color: Theme.fill(page.st)
                border.color: page.st === "idle" ? Theme.line : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.calm } }
                clip: true

                // Running: the last three minutes of processes along the floor.
                Pulse {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 1 }
                    height: 56
                    samples: guard.pulse[page.agentId] || []
                    color: page.fore
                    opacity: page.st === "running" ? 0.5 : page.st === "idle" ? 0.25 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.calm } }
                }

                RowLayout {
                    anchors { left: parent.left; top: parent.top; margins: 34; topMargin: 40 }
                    spacing: 10
                    StateMark {
                        state: page.st
                        tint: page.fore
                        Layout.alignment: Qt.AlignVCenter
                    }
                    Text {
                        text: page.st === "open" ? "OPEN" : page.st === "running" ? "RUNNING" : "IDLE"
                        color: page.fore
                        font.family: Theme.mono
                        font.pixelSize: 12
                        font.letterSpacing: 2.4
                        font.weight: Font.DemiBold
                    }
                    Text {
                        text: page.st === "running" ? "·  " + page.procs + (page.procs === 1 ? " process" : " processes") : ""
                        color: Theme.soft(page.st)
                        font.family: Theme.mono
                        font.pixelSize: 12
                        font.letterSpacing: 1.2
                    }
                }

                Column {
                    anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 34; rightMargin: 34; topMargin: 112 }
                    spacing: 12
                    AgentName {
                        width: parent.width
                        text: page.agent.name
                        held: page.st !== "open"
                        size: Math.min(104, Math.max(56, hero.width / 8.5))
                        tracking: -3.5
                        color: page.fore
                        outline: Theme.bright
                    }
                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: page.st === "running" ? "Held by " + page.agent.profile + ". Reach changes load while it runs."
                            : page.st === "idle" ? "Held, at rest. It starts through the launcher, never around it."
                            : !page.agent.guarded ? page.agent.entry + " no longer runs the launcher. Guard it again in Settings."
                            : page.agent.profile + " is not enforcing. Reinstall the package."
                        color: Theme.soft(page.st)
                        font.family: Theme.serif
                        font.italic: true
                        font.pixelSize: 17
                        textFormat: Text.PlainText
                    }
                }

                // The actions that matter in this state, top right.
                Row {
                    id: actions
                    anchors { right: parent.right; top: parent.top; rightMargin: 30; topMargin: 22 }
                    spacing: 26
                    visible: page.st !== "open"

                    Field {
                        id: folder
                        anchors.verticalCenter: parent.verticalCenter
                        visible: page.agent.terminal
                        width: 170
                        text: guard.folderFor(page.agentId)
                        color: page.fore
                        lineColor: Theme.soft(page.st)
                        focusColor: page.st === "running" ? page.fore : Theme.red
                        placeholderText: "Folder"
                        placeholderTextColor: Theme.soft(page.st)
                        onAccepted: guard.launch(page.agentId, text)
                        Q.ToolTip.visible: hovered
                        Q.ToolTip.delay: 500
                        Q.ToolTip.text: "Where it starts; Enter starts it"
                    }
                    RoundAction {
                        visible: page.st === "idle" || page.agent.terminal
                        size: 48
                        glyph: "▶"
                        text: page.st === "running" ? "New session" : "Start"
                        labelSize: 15
                        note: page.agent.terminal ? "In Konsole" : "Through the launcher"
                        disc: page.st === "running" ? Theme.paper : Theme.red
                        glyphColor: page.st === "running" ? Theme.ink : Theme.bright
                        labelColor: page.fore
                        noteColor: Theme.soft(page.st)
                        onClicked: guard.launch(page.agentId, folder.text)
                    }
                    RoundAction {
                        visible: page.st === "running"
                        size: 48
                        glyph: "■"
                        text: page.confirmStop ? "Stop " + page.procs + "?" : "Stop"
                        labelSize: 15
                        note: page.confirmStop ? "Click again" : "Every process"
                        disc: "transparent"
                        glyphColor: page.confirmStop ? Theme.red : page.fore
                        labelColor: page.confirmStop ? Theme.red : page.fore
                        noteColor: Theme.soft(page.st)
                        Rectangle {
                            width: parent.size; height: width; radius: width / 2
                            color: page.confirmStop ? Theme.paper : "transparent"
                            border.color: page.fore; border.width: 1.5
                            z: -1
                        }
                        onClicked: {
                            if (page.confirmStop) { guard.stop(page.agentId); page.confirmStop = false }
                            else { page.confirmStop = true; unconfirm.restart() }
                        }
                    }
                }
                // Open: nothing to start; say where to look.
                TextAction {
                    anchors { right: parent.right; top: parent.top; rightMargin: 34; topMargin: 32 }
                    visible: page.st === "open"
                    glyph: "→"
                    text: "What the check says"
                    labelColor: Theme.bright
                    onClicked: page.nav.open("integrity")
                }
                Text {
                    anchors { right: parent.right; top: actions.bottom; rightMargin: 30; topMargin: 10 }
                    visible: guard.message !== ""
                    text: guard.message
                    color: page.fore
                    font.family: Theme.sans
                    font.pixelSize: 12
                    textFormat: Text.PlainText
                }
            }

            // Its numbers, large: the things worth a glance.
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 30
                spacing: 0
                Stat {
                    Layout.fillWidth: true; Layout.preferredWidth: 1
                    value: page.reach; label: page.reach === 1 ? "place it reaches" : "places it reaches"
                    color: page.change.changed.length || page.change.removed.length ? Theme.red : Theme.ink
                }
                Stat {
                    Layout.fillWidth: true; Layout.preferredWidth: 1
                    value: page.writable; label: "it can write"
                }
                Stat {
                    Layout.fillWidth: true; Layout.preferredWidth: 1
                    value: page.refusedDay; label: "refused, 24 hours"
                }
                Stat {
                    Layout.fillWidth: true; Layout.preferredWidth: 1
                    value: page.section.github_token ? "Yes" : "No"; label: page.change.token ? "GitHub token · edited" : "GitHub token"
                    color: page.change.token ? Theme.red : Theme.ink
                }
            }

            // Reach: the policy paths, edited in place.
            Heading { title: "Reach"; note: "Where it may go besides its own state. Deny wins over any allow." }
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 20
                Caption { Layout.fillWidth: true; Layout.leftMargin: 20; text: "Path" }
                Caption { Layout.preferredWidth: 4 * 40 + 9; text: "Read  Write  Run  Deny" }
                Item { Layout.preferredWidth: 28 }
            }
            Rule { Layout.fillWidth: true; Layout.topMargin: 8 }
            Repeater {
                model: page.paths
                Item {
                    id: pathRow
                    required property var modelData
                    required property int index
                    readonly property bool edited: page.change.changed.indexOf(modelData.path) >= 0
                    readonly property string access: modelData.access
                    Layout.fillWidth: true
                    implicitHeight: 58
                    Rectangle {
                        anchors.fill: parent
                        color: pathRow.edited ? Theme.redWash : hover.containsMouse ? Theme.faint : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.quick } }
                    }
                    MouseArea { id: hover; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
                    // Weight bar: how much it may do there, at a glance.
                    Rectangle {
                        x: 0
                        anchors.verticalCenter: parent.verticalCenter
                        width: pathRow.access === "none" ? 3 : 2 + 2 * pathRow.access.length
                        height: 30
                        color: pathRow.edited || pathRow.access === "none" ? Theme.red : Theme.ink
                        opacity: pathRow.access === "r" ? 0.4 : 1
                        Behavior on width { NumberAnimation { duration: Theme.quick } }
                    }
                    RowLayout {
                        anchors { fill: parent; leftMargin: 20 }
                        spacing: 12
                        Text {
                            Layout.fillWidth: true
                            text: pathRow.modelData.path
                            color: pathRow.access === "none" ? Theme.red : Theme.ink
                            font.family: Theme.mono
                            font.pixelSize: 15
                            font.weight: pathRow.access.indexOf("w") >= 0 ? Font.DemiBold : Font.Normal
                            font.strikeout: pathRow.access === "none"
                            elide: Text.ElideMiddle
                            textFormat: Text.PlainText
                        }
                        Caption {
                            visible: pathRow.edited
                            color: Theme.red
                            text: "edited"
                        }
                        AccessPicker {
                            cell: 37
                            access: pathRow.access
                            onPicked: access => guard.setAccess(page.agentId, pathRow.index, access)
                        }
                        TextAction {
                            Layout.preferredWidth: 28
                            glyph: "×"
                            quiet: true
                            Accessible.name: "Remove " + pathRow.modelData.path
                            onClicked: guard.removePath(page.agentId, pathRow.index)
                        }
                    }
                    Rule { width: parent.width; anchors.bottom: parent.bottom; color: Theme.faint }
                }
            }
            Repeater {
                model: page.change.removed
                Item {
                    required property string modelData
                    Layout.fillWidth: true
                    implicitHeight: 44
                    Rectangle { anchors.fill: parent; color: Theme.redWash }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 20
                        text: parent.modelData + "   removed"
                        color: Theme.red
                        font.family: Theme.mono
                        font.pixelSize: 14
                        font.strikeout: true
                        textFormat: Text.PlainText
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 16
                spacing: 12
                Text { Layout.leftMargin: 4; text: "+"; color: Theme.red; font.family: Theme.sans; font.pixelSize: 20 }
                Field {
                    id: newPath
                    Layout.fillWidth: true
                    placeholderText: "Add a path: ~/folder/ or ~/file"
                    onAccepted: add.clicked()
                }
                TextAction { text: "Browse"; quiet: true; onClicked: folderDialog.open() }
                AccessPicker { cell: 37; access: page.newAccess; onPicked: access => page.newAccess = access }
                TextAction {
                    id: add
                    Layout.preferredWidth: 28
                    text: "Add"
                    accent: true
                    enabled: newPath.text.trim() !== ""
                    onClicked: { guard.addPath(page.agentId, newPath.text, page.newAccess); newPath.clear() }
                }
            }
            FolderDialog {
                id: folderDialog
                onAccepted: newPath.text = guard.folderPath(selectedFolder)
            }

            RowLayout {
                Layout.topMargin: 30
                spacing: 18
                Toggle {
                    text: "Give it the GitHub token"
                    checked: page.section.github_token === true
                    onToggled: guard.setGithubToken(page.agentId, checked)
                }
                Text {
                    text: page.change.token ? "Takes effect on its next start." : "GH_TOKEN, read on start."
                    color: page.change.token ? Theme.red : Theme.muted
                    font.family: Theme.serif
                    font.italic: true
                    font.pixelSize: 13
                }
            }

            // What it tried and was refused: the last day as bars, then the newest.
            Heading {
                title: "Refused"
                note: page.denials.length ? "Allow adds a draft entry; nothing loads until you apply."
                                          : "Nothing this boot."
            }
            Bars {
                Layout.fillWidth: true
                Layout.topMargin: 20
                implicitHeight: 84
                buckets: guard.denialHours
                agent: page.agentId
            }
            Rule { Layout.fillWidth: true; Layout.topMargin: 14; visible: page.denials.length > 0 }
            Repeater {
                model: page.denials.slice(0, 8)
                Item {
                    id: denialRow
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 56
                    RowLayout {
                        anchors.fill: parent
                        spacing: 18
                        Text {
                            Layout.preferredWidth: 46
                            horizontalAlignment: Text.AlignRight
                            text: denialRow.modelData.count + "×"
                            color: denialRow.modelData.count > 9 ? Theme.red : Theme.ink
                            font.family: Theme.sans
                            font.pixelSize: 20
                            font.weight: Font.Medium
                        }
                        Column {
                            Layout.fillWidth: true
                            spacing: 3
                            Text {
                                width: parent.width
                                text: denialRow.modelData.name || denialRow.modelData.operation
                                color: Theme.ink
                                font.family: Theme.mono
                                font.pixelSize: 13
                                elide: Text.ElideMiddle
                                textFormat: Text.PlainText
                            }
                            Caption {
                                width: parent.width
                                elide: Text.ElideRight
                                text: denialRow.modelData.time + " · " + denialRow.modelData.operation + " "
                                      + denialRow.modelData.mask + " · " + denialRow.modelData.comm
                            }
                        }
                        TextAction {
                            visible: denialRow.modelData.access !== ""
                            accent: true
                            glyph: "+"
                            text: "Allow " + denialRow.modelData.access.toUpperCase()
                            onClicked: guard.addPath(page.agentId, denialRow.modelData.name, denialRow.modelData.access)
                        }
                    }
                    Rule { width: parent.width; anchors.bottom: parent.bottom; color: Theme.faint }
                }
            }
            TextAction {
                Layout.topMargin: 16
                visible: page.denials.length > 8
                quiet: true
                glyph: "→"
                text: "All " + page.denials.length + " in Activity"
                onClicked: page.nav.open("activity")
            }

            // Its own log: starts, stops, guard changes.
            Heading { title: "Log"; note: page.log.length ? "Kept for 60 days on this machine." : "Nothing recorded yet." }
            Item { implicitHeight: 14 }
            Repeater {
                model: page.log
                RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 32
                    spacing: 18
                    Caption { Layout.preferredWidth: 110; text: parent.modelData.when }
                    Rectangle {
                        implicitWidth: 6; implicitHeight: 6; radius: 1
                        color: parent.modelData.kind === "open" ? Theme.red : Theme.ink
                        opacity: parent.modelData.kind === "end" || parent.modelData.kind === "stop" ? 0.35 : 1
                    }
                    Text {
                        Layout.fillWidth: true
                        text: parent.modelData.text.replace(/^./, c => c.toUpperCase())
                        color: parent.modelData.kind === "open" ? Theme.red : Theme.ink
                        font.family: Theme.sans
                        font.pixelSize: 13
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
