// Harness Guard console. Every string that may come from an agent (paths, process
// names, check output) is shown with Text.PlainText so it can't inject markup or links.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.ApplicationWindow {
    id: root

    title: "Harness Guard"
    width: Kirigami.Units.gridUnit * 64
    height: Kirigami.Units.gridUnit * 42

    readonly property var accessModes: [
        { value: "none", text: "Deny" },
        { value: "r", text: "Read" },
        { value: "rx", text: "Read, run" },
        { value: "rw", text: "Read, write" },
        { value: "rwx", text: "Read, write, run" },
    ]
    property string permAgent: guard.agents.length ? guard.agents[0].id : ""

    function agentName(id) {
        const agent = guard.agents.find(a => a.id === id)
        return agent ? agent.name : id
    }
    function show(page) {
        pageStack.clear()
        pageStack.push(page)
    }

    globalDrawer: Kirigami.GlobalDrawer {
        modal: false
        collapsible: true
        actions: [
            Kirigami.Action { text: "Agents"; icon.name: "system-users"; onTriggered: root.show(agentsPage) },
            Kirigami.Action { text: "Permissions"; icon.name: "document-edit"; onTriggered: root.show(permissionsPage) },
            Kirigami.Action { text: "Activity"; icon.name: "view-list-text"; onTriggered: root.show(activityPage) },
            Kirigami.Action { text: "Integrity"; icon.name: "security-high"; onTriggered: root.show(integrityPage) }
        ]
    }

    pageStack.initialPage: agentsPage
    pageStack.defaultColumnWidth: Kirigami.Units.gridUnit * 34

    component Status: RowLayout {
        property bool good
        property string text
        spacing: Kirigami.Units.smallSpacing
        Kirigami.Icon {
            source: parent.good ? "emblem-ok-symbolic" : "emblem-error"
            implicitWidth: Kirigami.Units.iconSizes.small
            implicitHeight: implicitWidth
        }
        QQC2.Label { text: parent.text }
    }

    Component {
        id: agentsPage
        Kirigami.ScrollablePage {
            title: "Agents"
            actions: [Kirigami.Action { text: "Refresh"; icon.name: "view-refresh"; onTriggered: guard.refresh() }]

            ListView {
                model: guard.agents
                delegate: QQC2.ItemDelegate {
                    required property var modelData
                    width: ListView.view.width
                    onClicked: { root.permAgent = modelData.id; root.show(permissionsPage) }
                    contentItem: RowLayout {
                        spacing: Kirigami.Units.largeSpacing
                        ColumnLayout {
                            Layout.fillWidth: true
                            Kirigami.Heading { level: 3; text: modelData.name; textFormat: Text.PlainText }
                            QQC2.Label {
                                Layout.fillWidth: true
                                text: modelData.profile + " · " + modelData.entry
                                textFormat: Text.PlainText
                                elide: Text.ElideMiddle
                                opacity: 0.7
                            }
                        }
                        Status { good: modelData.guarded; text: good ? "Guarded" : "Not guarded" }
                        Status { good: modelData.enforcing; text: good ? "Enforcing" : "Not enforcing" }
                        QQC2.Label {
                            Layout.minimumWidth: Kirigami.Units.gridUnit * 5
                            text: (guard.running[modelData.id] || 0) + " processes"
                        }
                        QQC2.Label {
                            Layout.minimumWidth: Kirigami.Units.gridUnit * 5
                            text: modelData.version || "…"
                            textFormat: Text.PlainText
                        }
                    }
                }
            }
        }
    }

    Component {
        id: integrityPage
        Kirigami.ScrollablePage {
            title: "Integrity"
            actions: [Kirigami.Action {
                text: guard.checkExit === -2 ? "Checking…" : "Run check"
                icon.name: "view-refresh"
                enabled: guard.checkExit !== -2
                onTriggered: guard.runCheck()
            }]
            Component.onCompleted: if (guard.checkExit === -1) guard.runCheck()
            header: Kirigami.InlineMessage {
                position: Kirigami.InlineMessage.Position.Header
                visible: guard.checkExit >= 0
                type: guard.checkExit === 0 ? Kirigami.MessageType.Positive : Kirigami.MessageType.Error
                text: guard.checkExit === 0 ? "Every check passed." : "Some checks failed; see FAIL below."
            }

            ListView {
                model: guard.checkLines
                delegate: RowLayout {
                    required property var modelData
                    width: ListView.view.width
                    spacing: Kirigami.Units.smallSpacing
                    Item {
                        implicitWidth: Kirigami.Units.iconSizes.small
                        implicitHeight: implicitWidth
                        Kirigami.Icon {
                            anchors.fill: parent
                            visible: modelData.kind === "ok" || modelData.kind === "fail"
                            source: modelData.kind === "ok" ? "emblem-ok-symbolic" : "emblem-error"
                        }
                    }
                    QQC2.Label {
                        Layout.fillWidth: true
                        Layout.topMargin: modelData.kind === "head" ? Kirigami.Units.largeSpacing : 0
                        text: modelData.text.replace(/^(ok|FAIL) +/, "")
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
                        font.bold: modelData.kind === "head"
                        font.family: modelData.kind === "info" ? "monospace" : Kirigami.Theme.defaultFont.family
                        color: modelData.kind === "fail" ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
                    }
                }
            }
        }
    }

    Component {
        id: activityPage
        Kirigami.ScrollablePage {
            id: activity
            title: "Activity"
            property string filter: ""
            actions: [Kirigami.Action { text: "Clear"; icon.name: "edit-clear-history"; onTriggered: guard.clearDenials() }]
            header: ColumnLayout {
                spacing: 0
                Kirigami.InlineMessage {
                    Layout.fillWidth: true
                    position: Kirigami.InlineMessage.Position.Header
                    visible: guard.journalError !== ""
                    type: Kirigami.MessageType.Warning
                    text: "Can't follow the kernel journal: " + guard.journalError
                }
                QQC2.ToolBar {
                    Layout.fillWidth: true
                    RowLayout {
                        QQC2.Label { text: "AppArmor denials this boot, newest first, for" }
                        QQC2.ComboBox {
                            model: [{ id: "", name: "all agents" }].concat(guard.agents)
                            textRole: "name"
                            valueRole: "id"
                            onActivated: activity.filter = currentValue
                        }
                    }
                }
            }

            ListView {
                model: guard.denials.filter(d => activity.filter === "" || d.agent === activity.filter)
                delegate: QQC2.ItemDelegate {
                    required property var modelData
                    width: ListView.view.width
                    hoverEnabled: false
                    contentItem: RowLayout {
                        ColumnLayout {
                            Layout.fillWidth: true
                            QQC2.Label {
                                Layout.fillWidth: true
                                text: modelData.name || modelData.operation
                                textFormat: Text.PlainText
                                font.family: "monospace"
                                elide: Text.ElideMiddle
                            }
                            QQC2.Label {
                                Layout.fillWidth: true
                                text: root.agentName(modelData.agent) + " · " + modelData.operation + " "
                                      + modelData.mask + " · " + modelData.comm + " · " + modelData.count
                                      + "× · last " + modelData.time
                                textFormat: Text.PlainText
                                elide: Text.ElideRight
                                opacity: 0.7
                            }
                        }
                        QQC2.Button {
                            visible: modelData.access !== ""
                            text: "Allow…"
                            icon.name: "list-add"
                            QQC2.ToolTip.text: "Add " + modelData.name + " (" + modelData.access
                                               + ") to the draft policy for review"
                            QQC2.ToolTip.visible: hovered
                            onClicked: {
                                guard.addPath(modelData.agent, modelData.name, modelData.access)
                                root.permAgent = modelData.agent
                                root.show(permissionsPage)
                            }
                        }
                    }
                }
                Kirigami.PlaceholderMessage {
                    anchors.centerIn: parent
                    width: parent.width - Kirigami.Units.gridUnit * 4
                    visible: parent.count === 0
                    text: "No denials"
                }
            }
        }
    }

    Component {
        id: permissionsPage
        Kirigami.ScrollablePage {
            id: permissions
            title: "Permissions"
            readonly property var section: guard.draft[root.permAgent] || { paths: [] }
            actions: [
                Kirigami.Action {
                    text: "Review and apply…"
                    icon.name: "dialog-ok-apply"
                    enabled: guard.dirty
                    onTriggered: { guard.makeReview(); pageStack.push(reviewPage) }
                },
                Kirigami.Action {
                    text: "Discard changes"
                    icon.name: "edit-undo"
                    enabled: guard.dirty
                    onTriggered: guard.discard()
                }
            ]
            header: ColumnLayout {
                spacing: 0
                QQC2.TabBar {
                    Layout.fillWidth: true
                    currentIndex: guard.agents.findIndex(a => a.id === root.permAgent)
                    Repeater {
                        model: guard.agents
                        QQC2.TabButton {
                            required property var modelData
                            text: modelData.name
                            onClicked: root.permAgent = modelData.id
                        }
                    }
                }
                Kirigami.InlineMessage {
                    Layout.fillWidth: true
                    position: Kirigami.InlineMessage.Position.Header
                    visible: guard.dirty
                    text: "Unapplied changes. Path changes reach running agents within a second of applying; the GitHub token on their next start."
                }
            }

            ListView {
                id: pathList
                model: permissions.section.paths
                header: Kirigami.FormLayout {
                    width: pathList.width
                    QQC2.Switch {
                        Kirigami.FormData.label: "GitHub token:"
                        text: "Pass GH_TOKEN (on the agent's next start)"
                        checked: permissions.section.github_token === true
                        onToggled: guard.setGithubToken(root.permAgent, checked)
                    }
                    RowLayout {
                        Kirigami.FormData.label: "Add path:"
                        QQC2.TextField {
                            id: newPath
                            Layout.fillWidth: true
                            placeholderText: "~/folder/ or ~/file"
                            onAccepted: addButton.clicked()
                        }
                        QQC2.Button {
                            text: "Browse…"
                            icon.name: "folder-open"
                            onClicked: folderDialog.open()
                        }
                        QQC2.ComboBox {
                            id: newAccess
                            model: root.accessModes
                            textRole: "text"
                            valueRole: "value"
                            currentIndex: 1
                        }
                        QQC2.Button {
                            id: addButton
                            text: "Add"
                            icon.name: "list-add"
                            enabled: newPath.text.trim() !== ""
                            onClicked: { guard.addPath(root.permAgent, newPath.text, newAccess.currentValue); newPath.clear() }
                        }
                    }
                    FolderDialog {
                        id: folderDialog
                        onAccepted: newPath.text = guard.folderPath(selectedFolder)
                    }
                }
                delegate: QQC2.ItemDelegate {
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    hoverEnabled: false
                    contentItem: RowLayout {
                        QQC2.Label {
                            Layout.fillWidth: true
                            text: modelData.path
                            textFormat: Text.PlainText
                            font.family: "monospace"
                            elide: Text.ElideMiddle
                        }
                        QQC2.ComboBox {
                            model: root.accessModes
                            textRole: "text"
                            valueRole: "value"
                            currentIndex: root.accessModes.findIndex(m => m.value === modelData.access)
                            onActivated: guard.setAccess(root.permAgent, index, currentValue)
                        }
                        QQC2.ToolButton {
                            icon.name: "list-remove"
                            QQC2.ToolTip.text: "Remove"
                            QQC2.ToolTip.visible: hovered
                            onClicked: guard.removePath(root.permAgent, index)
                        }
                    }
                }
                footer: QQC2.Label {
                    width: pathList.width
                    padding: Kirigami.Units.largeSpacing
                    wrapMode: Text.Wrap
                    opacity: 0.7
                    text: "Deny wins over any allow. The agent's own state, keys, wallets and browser profiles are set by its profile, not here. Write access to places unguarded programs run or read config from is refused when you apply."
                }
            }
        }
    }

    Component {
        id: reviewPage
        Kirigami.ScrollablePage {
            title: "Review"
            actions: [Kirigami.Action {
                text: guard.applyExit === -2 ? "Applying…" : "Apply (asks for your password)"
                icon.name: "dialog-password"
                enabled: guard.reviewOk && guard.applyExit !== -2
                onTriggered: guard.applyReview()
            }]
            header: Kirigami.InlineMessage {
                position: Kirigami.InlineMessage.Position.Header
                visible: guard.applyExit >= 0
                type: guard.applyExit === 0 ? Kirigami.MessageType.Positive : Kirigami.MessageType.Error
                text: guard.applyExit === 0 ? "Applied. " + guard.applyOutput : guard.applyOutput
            }

            ListView {
                model: guard.review
                delegate: QQC2.Label {
                    required property var modelData
                    width: ListView.view.width
                    text: modelData.text
                    textFormat: Text.PlainText
                    wrapMode: Text.WrapAnywhere
                    font.family: "monospace"
                    font.bold: modelData.kind === "h"
                    color: modelData.kind === "+" ? Kirigami.Theme.positiveTextColor
                         : modelData.kind === "-" ? Kirigami.Theme.negativeTextColor
                         : modelData.kind === "@" ? Kirigami.Theme.disabledTextColor
                         : Kirigami.Theme.textColor
                }
            }
        }
    }
}
