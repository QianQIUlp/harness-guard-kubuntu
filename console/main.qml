// Harness Guard console. Every string that may come from an agent (paths, process
// names, check output) is shown as plain text so it can't inject markup or links.
import QtQuick
import QtQuick.Controls.Basic as Q
import QtQuick.Layouts

Q.ApplicationWindow {
    id: window

    title: "Harness Guard"
    width: 1240
    height: 820
    minimumWidth: 980
    minimumHeight: 640
    visible: !startHidden
    color: Theme.paper
    font.family: Theme.sans

    property string page: "overview"
    property string agent: ""
    property bool reviewing: false

    function open(name, id) {
        if (id !== undefined)
            agent = id
        page = name
    }
    function agentById(id) {
        return guard.agents.find(a => a.id === id)
    }
    function held(a) {
        return !!a && a.guarded && a.enforcing
    }

    // Closing keeps watching from the tray (if there is one and it's wanted).
    onClosing: close => {
        if (hasTray && guard.settings.tray) {
            close.accepted = false
            window.hide()
        }
    }
    Connections {
        target: guard
        function onShowRequested() { window.show(); window.raise(); window.requestActivate() }
    }

    component NavItem: Q.AbstractButton {
        id: item
        property bool current: false
        property string meta: ""
        property bool good: true
        property bool live: false
        property bool dot: false
        property string mark: ""
        width: parent ? parent.width : 0
        height: 34
        hoverEnabled: true
        focusPolicy: Qt.StrongFocus
        background: Rectangle {
            color: item.current ? Theme.faint : item.hovered ? Qt.alpha(Theme.ink, 0.04) : "transparent"
            radius: 4
            Rectangle {
                width: 2
                height: 14
                radius: 1
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.red
                visible: item.current
            }
            border.color: item.visualFocus ? Theme.red : "transparent"
        }
        contentItem: RowLayout {
            spacing: 10
            Item {
                Layout.leftMargin: 14
                implicitWidth: 9
                implicitHeight: 9
                visible: item.dot || item.mark !== ""
                Dot { anchors.fill: parent; visible: item.mark === ""; good: item.good; live: item.live; hollow: !item.good }
                StateMark { anchors.fill: parent; visible: item.mark !== ""; state: item.mark || "idle" }
            }
            Text {
                Layout.leftMargin: item.dot || item.mark !== "" ? 0 : 14
                Layout.fillWidth: true
                text: item.text
                color: Theme.ink
                font.family: Theme.sans
                font.pixelSize: 13
                font.weight: item.current ? Font.DemiBold : Font.Normal
                elide: Text.ElideRight
                textFormat: Text.PlainText
            }
            Text {
                Layout.rightMargin: 12
                text: item.meta
                color: item.good ? Theme.muted : Theme.red
                font.family: Theme.mono
                font.pixelSize: 11
                textFormat: Text.PlainText
            }
        }
    }

    // Rail: wordmark, places, and a small map of the four guards.
    Item {
        id: rail
        width: 236
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }

        Column {
            id: brand
            x: 26
            y: 28
            spacing: 6
            Row {
                spacing: 10
                Text {
                    text: "Guard"
                    color: Theme.ink
                    font.family: Theme.sans
                    font.pixelSize: 28
                    font.weight: Font.Bold
                    font.letterSpacing: -1
                }
                Text {
                    text: "+"
                    color: Theme.red
                    font.family: Theme.sans
                    font.pixelSize: 28
                    font.weight: Font.Light
                }
            }
            Caption { text: "Harness guard · " + guard.host }
        }

        Column {
            anchors { left: parent.left; right: parent.right; top: brand.bottom; margins: 12; topMargin: 36 }
            spacing: 2

            NavItem {
                text: "Overview"
                current: window.page === "overview"
                onClicked: window.open("overview")
            }
            Item { width: 1; height: 18 }
            Caption { x: 14; text: "Agents"; bottomPadding: 6 }
            Repeater {
                model: guard.agents
                NavItem {
                    required property var modelData
                    text: modelData.name
                    mark: Theme.stateOf(modelData, guard.running[modelData.id] || 0)
                    good: !guard.changes[modelData.id]
                    meta: guard.changes[modelData.id] ? "edited" : (guard.running[modelData.id] || "")
                    current: window.page === "agent" && window.agent === modelData.id
                    onClicked: window.open("agent", modelData.id)
                }
            }
            Item { width: 1; height: 18 }
            Caption { x: 14; text: "Machine"; bottomPadding: 6 }
            NavItem {
                text: "Activity"
                meta: guard.denials.length ? String(guard.denials.reduce((n, d) => n + d.count, 0)) : ""
                current: window.page === "activity"
                onClicked: window.open("activity")
            }
            NavItem {
                text: "Integrity"
                dot: true
                good: guard.checkExit === 0 || guard.checkExit < 0
                live: guard.checkExit === -2
                meta: guard.checkExit === -2 ? "…" : guard.checkTime
                current: window.page === "integrity"
                onClicked: window.open("integrity")
            }
            NavItem {
                text: "Settings"
                current: window.page === "settings"
                onClicked: window.open("settings")
            }
        }

        // Map: one point per agent, like the site's room map. Red marks one not held.
        Column {
            anchors { left: parent.left; bottom: parent.bottom; leftMargin: 26; bottomMargin: 26 }
            spacing: 12
            Grid {
                columns: 2
                spacing: 22
                Repeater {
                    model: guard.agents
                    Item {
                        required property var modelData
                        width: 10
                        height: 10
                        StateMark {
                            anchors.centerIn: parent
                            width: window.page === "agent" && window.agent === parent.modelData.id ? 12 : 8
                            height: width
                            state: Theme.stateOf(parent.modelData, guard.running[parent.modelData.id] || 0)
                            Behavior on width { NumberAnimation { duration: Theme.quick } }
                        }
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -8
                            cursorShape: Qt.PointingHandCursor
                            onClicked: window.open("agent", parent.modelData.id)
                        }
                    }
                }
            }
            Caption { text: "Policy " + guard.policyId }
        }
    }
    Rule { width: 1; anchors { left: rail.right; top: parent.top; bottom: parent.bottom } }

    // Pages fade and settle in; the change bar sits under them while a draft exists.
    Item {
        id: stage
        anchors { left: rail.right; leftMargin: 1; right: parent.right; top: parent.top; bottom: changeBar.top }
        clip: true

        Loader {
            id: pageLoader
            anchors.fill: parent
            sourceComponent: ({ overview: overviewPage, agent: agentPage, activity: activityPage,
                                integrity: integrityPage, settings: settingsPage })[window.page]
            onLoaded: { item.opacity = 0; settle.restart() }
            ParallelAnimation {
                id: settle
                NumberAnimation { target: pageLoader.item; property: "opacity"; from: 0; to: 1; duration: Theme.calm; easing.type: Easing.OutCubic }
                NumberAnimation { target: pageLoader.item; property: "y"; from: 10; to: 0; duration: Theme.calm; easing.type: Easing.OutCubic }
            }
        }
        Component { id: overviewPage; OverviewPage { nav: window } }
        Component { id: agentPage; AgentPage { nav: window; agentId: window.agent } }
        Component { id: activityPage; ActivityPage { nav: window } }
        Component { id: integrityPage; IntegrityPage { nav: window } }
        Component { id: settingsPage; SettingsPage { nav: window } }
    }

    Item {
        id: changeBar
        anchors { left: rail.right; leftMargin: 1; right: parent.right; bottom: parent.bottom }
        height: guard.dirty ? 84 : 0
        clip: true
        Behavior on height { NumberAnimation { duration: Theme.calm; easing.type: Easing.OutCubic } }

        Rule { width: parent.width }
        RowLayout {
            anchors { fill: parent; leftMargin: Theme.gutter; rightMargin: Theme.gutter }
            spacing: 28
            Dot { good: false }
            Column {
                Layout.fillWidth: true
                spacing: 4
                Text {
                    text: guard.changeCount === 1 ? "One change, not applied yet." : guard.changeCount + " changes, not applied yet."
                    color: Theme.ink
                    font.family: Theme.sans
                    font.pixelSize: 15
                }
                Caption {
                    text: Object.keys(guard.changes).map(id => (window.agentById(id) || { name: id }).name).join(" · ")
                }
            }
            TextAction { text: "Discard"; quiet: true; onClicked: guard.discard() }
            RoundAction {
                text: "Review"
                note: "See the rules before they load"
                onClicked: { guard.makeReview(); window.reviewing = true }
            }
        }
    }

    ReviewSheet {
        anchors.fill: parent
        open: window.reviewing
        onClosed: window.reviewing = false
    }

    Shortcut { sequence: "Esc"; enabled: window.reviewing; onActivated: window.reviewing = false }
    Shortcut { sequence: "Ctrl+1"; onActivated: window.open("overview") }
    Shortcut { sequence: "Ctrl+2"; onActivated: window.open("activity") }
    Shortcut { sequence: "Ctrl+3"; onActivated: window.open("integrity") }
    Shortcut { sequences: [StandardKey.Quit]; onActivated: Qt.quit() }
    Shortcut { sequences: [StandardKey.Refresh]; onActivated: { guard.refresh(); guard.runCheck() } }
}
