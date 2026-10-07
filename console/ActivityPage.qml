// AppArmor denials as they happen, grouped by what was refused.
import QtQuick
import QtQuick.Controls.Basic as Q
import QtQuick.Layouts

Item {
    id: page
    property var nav
    property string filter: ""
    property bool logView: false
    readonly property int month: guard.denialDays.reduce((n, b) => n + (filter === "" ? b.total : (b.agents[filter] || 0)), 0)
    readonly property var shown: guard.denials.filter(d => filter === "" || d.agent === filter)
    readonly property int total: shown.reduce((n, d) => n + d.count, 0)

    ColumnLayout {
        anchors { fill: parent; margins: Theme.gutter; bottomMargin: 0 }
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Dot { width: 6; height: 6; good: guard.journalError === ""; live: guard.journalError === "" }
            Caption { text: guard.journalError === "" ? "Activity · following the kernel journal" : "Activity · not following" }
            Item { Layout.fillWidth: true }
            TextAction { text: "Clear"; quiet: true; enabled: guard.denials.length > 0; onClicked: guard.clearDenials() }
        }

        RowLayout {
            Layout.topMargin: 22
            Layout.fillWidth: true
            spacing: 40
            Column {
                Layout.alignment: Qt.AlignBottom
                spacing: 6
                Text {
                    text: page.total
                    color: Theme.ink
                    font.family: Theme.sans
                    font.pixelSize: 84
                    font.weight: Font.Bold
                    font.letterSpacing: -4
                }
                Caption { text: "refused this boot · " + page.month + " in 30 days" }
            }
            Bars {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignBottom
                implicitHeight: 110
                buckets: guard.denialDays
                agent: page.filter
                format: "d MMM"
            }
        }
        Text {
            Layout.topMargin: 10
            Layout.fillWidth: true
            visible: guard.journalError !== ""
            text: "Can't read the kernel journal: " + guard.journalError
            color: Theme.red
            font.family: Theme.serif
            font.italic: true
            font.pixelSize: 14
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
        }

        Flow {
            Layout.topMargin: 28
            Layout.fillWidth: true
            spacing: 26
            TextAction {
                text: page.logView ? "Refusals" : "Log"
                glyph: "⇄"
                accent: true
                onClicked: page.logView = !page.logView
            }
            Item { width: 1; height: 28; Rectangle { width: 1; height: 18; y: 5; color: Theme.line } }
            TextAction {
                text: "All"
                current: page.filter === ""
                quiet: page.filter !== ""
                onClicked: page.filter = ""
            }
            Repeater {
                model: guard.agents
                TextAction {
                    required property var modelData
                    text: modelData.name + "  " + (guard.denialCounts[modelData.id] || 0)
                    current: page.filter === modelData.id
                    quiet: page.filter !== modelData.id
                    onClicked: page.filter = modelData.id
                }
            }
        }
        Rule { Layout.fillWidth: true; Layout.topMargin: 18 }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: page.logView ? [] : page.shown
            visible: !page.logView
            boundsBehavior: Flickable.StopAtBounds
            Q.ScrollBar.vertical: Q.ScrollBar {}
            add: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.calm } }

            delegate: Item {
                id: row
                required property var modelData
                width: list.width
                height: 58
                RowLayout {
                    anchors { fill: parent; rightMargin: 12 }
                    spacing: 20
                    Text {
                        Layout.preferredWidth: 64
                        text: row.modelData.time
                        color: Theme.muted
                        font.family: Theme.mono
                        font.pixelSize: 12
                    }
                    Text {
                        Layout.preferredWidth: 150
                        text: (page.nav.agentById(row.modelData.agent) || { name: row.modelData.agent }).name
                        color: Theme.ink
                        font.family: Theme.sans
                        font.pixelSize: 13
                        elide: Text.ElideRight
                    }
                    Column {
                        Layout.fillWidth: true
                        spacing: 3
                        Text {
                            width: parent.width
                            text: row.modelData.name || row.modelData.operation
                            color: Theme.ink
                            font.family: Theme.mono
                            font.pixelSize: 13
                            elide: Text.ElideMiddle
                            textFormat: Text.PlainText
                        }
                        Caption {
                            width: parent.width
                            elide: Text.ElideRight
                            text: row.modelData.operation + " " + row.modelData.mask + " · " + row.modelData.comm
                        }
                    }
                    Text {
                        Layout.preferredWidth: 44
                        horizontalAlignment: Text.AlignRight
                        text: row.modelData.count + "×"
                        color: row.modelData.count > 9 ? Theme.red : Theme.muted
                        font.family: Theme.mono
                        font.pixelSize: 12
                    }
                    Item {
                        Layout.preferredWidth: 96
                        implicitHeight: allow.implicitHeight
                        TextAction {
                            id: allow
                            anchors.right: parent.right
                            visible: row.modelData.access !== ""
                            accent: true
                            text: "Allow " + row.modelData.access.toUpperCase()
                            onClicked: {
                                guard.addPath(row.modelData.agent, row.modelData.name, row.modelData.access)
                                page.nav.open("agent", row.modelData.agent)
                            }
                        }
                    }
                }
                Rule { width: parent.width; anchors.bottom: parent.bottom; color: Theme.faint }
            }

            Text {
                anchors.centerIn: parent
                visible: list.count === 0 && !page.logView
                text: "Quiet."
                color: Theme.muted
                font.family: Theme.serif
                font.italic: true
                font.pixelSize: 28
            }
        }
    
        // Everything the console has seen happen: starts, stops, guard changes, applies.
        ListView {
            id: log
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: page.logView
            clip: true
            model: page.logView ? guard.events.filter(e => page.filter === "" || e.agent === page.filter) : []
            boundsBehavior: Flickable.StopAtBounds
            Q.ScrollBar.vertical: Q.ScrollBar {}
            delegate: Item {
                id: entry
                required property var modelData
                width: log.width
                height: 44
                RowLayout {
                    anchors { fill: parent; rightMargin: 12 }
                    spacing: 20
                    Caption { Layout.preferredWidth: 110; text: entry.modelData.when }
                    StateMark {
                        state: entry.modelData.kind === "open" ? "open" : entry.modelData.kind === "run" || entry.modelData.kind === "start" ? "running" : "idle"
                    }
                    Text {
                        Layout.preferredWidth: 150
                        text: entry.modelData.agent ? (page.nav.agentById(entry.modelData.agent) || { name: entry.modelData.agent }).name : "Policy"
                        color: Theme.ink
                        font.family: Theme.sans
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                    }
                    Text {
                        Layout.fillWidth: true
                        text: entry.modelData.text
                        color: entry.modelData.kind === "open" ? Theme.red : Theme.ink
                        font.family: Theme.sans
                        font.pixelSize: 13
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                    }
                }
                Rule { width: parent.width; anchors.bottom: parent.bottom; color: Theme.faint }
            }
            Text {
                anchors.centerIn: parent
                visible: log.count === 0
                text: "Nothing logged yet."
                color: Theme.muted
                font.family: Theme.serif
                font.italic: true
                font.pixelSize: 28
            }
        }
    }
}
