// How the console itself behaves (tray, notifications, starting at login), and what is
// installed: the package, and each agent's receipt with Guard or Release.
import QtQuick
import QtQuick.Controls.Basic as Q
import QtQuick.Layouts

Item {
    id: page
    property var nav

    component Setting: RowLayout {
        id: setting
        property string key
        property string title
        property string note
        property bool available: true
        Layout.fillWidth: true
        Layout.topMargin: 26
        spacing: 24
        opacity: available ? 1 : 0.45
        Column {
            Layout.fillWidth: true
            spacing: 5
            Text {
                text: setting.title
                color: Theme.ink
                font.family: Theme.sans
                font.pixelSize: 17
                font.weight: Font.Medium
            }
            Text {
                width: parent.width
                text: setting.note
                color: Theme.muted
                font.family: Theme.serif
                font.italic: true
                font.pixelSize: 14
                wrapMode: Text.WordWrap
            }
        }
        Toggle {
            enabled: setting.available
            checked: guard.settings[setting.key] === true
            onToggled: guard.setSetting(setting.key, checked)
        }
    }

    Flickable {
        anchors.fill: parent
        contentHeight: column.implicitHeight + 2 * Theme.gutter
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: column
            x: Theme.gutter
            y: Theme.gutter
            width: Math.min(parent.width - 2 * Theme.gutter, 760)
            spacing: 0

            Caption { text: "Settings · this console" }
            Text {
                Layout.topMargin: 22
                textFormat: Text.StyledText
                text: "Keep watch,<br><font face='" + Theme.serif + "'><i>quietly.</i></font>"
                color: Theme.ink
                font.family: Theme.sans
                font.pixelSize: 52
                font.weight: Font.Medium
                font.letterSpacing: -1.8
                lineHeight: 1.02
            }
            Rule { Layout.fillWidth: true; Layout.topMargin: 36 }

            Setting {
                key: "tray"
                available: hasTray
                title: "Keep running in the tray"
                note: hasTray ? "Closing the window leaves the shield in the tray, still following the journal and the checks."
                              : "No system tray here, so closing the window quits."
            }
            Setting {
                key: "notify"
                available: hasTray
                title: "Tell me when something needs me"
                note: "A guard that opens, a check that starts failing, and what an agent was just refused (at most every ten minutes per agent). Silent while this window has focus."
            }
            Setting {
                key: "autostart"
                title: "Start at login, in the tray"
                note: "Writes ~/.config/autostart/harness-guard-console.desktop, which runs the installed, root-owned console. Agents can't write that folder."
            }

            Rule { Layout.fillWidth: true; Layout.topMargin: 36 }
            Caption {
                Layout.topMargin: 26
                text: "Installed · harness-guard " + (guard.setup.package || "(not from the package)")
            }
            Text {
                Layout.fillWidth: true
                Layout.topMargin: 8
                text: "Guarding an agent records what it changes first (in /var/lib/harness-guard/receipts); releasing puts exactly that back. Removing the package releases every agent."
                color: Theme.muted
                font.family: Theme.serif
                font.italic: true
                font.pixelSize: 14
                wrapMode: Text.WordWrap
            }
            Repeater {
                model: guard.setup.agents
                delegate: ColumnLayout {
                    id: receipt
                    required property var modelData
                    property bool open: false
                    // Guarded, but its entry point no longer runs the launcher (a vendor reinstall).
                    property bool broken: receipt.modelData.guarded
                        && guard.agents.some(a => a.id === receipt.modelData.agent && !a.guarded)
                    Layout.fillWidth: true
                    Layout.topMargin: 18
                    spacing: 6
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 16
                        Text {
                            text: receipt.modelData.name
                            color: Theme.ink
                            font.family: Theme.sans
                            font.pixelSize: 17
                            font.weight: Font.Medium
                            textFormat: Text.PlainText
                        }
                        Text {
                            Layout.fillWidth: true
                            text: receipt.broken ? "entry point replaced; guard it again"
                                  : receipt.modelData.guarded
                                  ? "guarded since " + Qt.formatDateTime(new Date(receipt.modelData.created * 1000), "d MMM yyyy HH:mm")
                                  : !receipt.modelData.present ? "not installed"
                                  : receipt.modelData.released ? "released by you" : "not guarded"
                            color: receipt.broken || receipt.modelData.present && !receipt.modelData.guarded && !receipt.modelData.released
                                   ? Theme.red : Theme.muted
                            font.family: Theme.mono
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }
                        TextAction {
                            visible: receipt.modelData.items.length > 0
                            quiet: true
                            text: receipt.open ? "Hide receipt" : "Receipt"
                            onClicked: receipt.open = !receipt.open
                        }
                        TextAction {
                            visible: receipt.broken
                            enabled: guard.setup.busy === "" && !(guard.running[receipt.modelData.agent] > 0)
                            accent: true
                            text: "Guard again"
                            onClicked: guard.setupAgent("guard", receipt.modelData.agent)
                        }
                        TextAction {
                            visible: receipt.modelData.present || receipt.modelData.guarded
                            enabled: guard.setup.busy === "" && !(guard.running[receipt.modelData.agent] > 0)
                            accent: !receipt.modelData.guarded
                            text: guard.setup.busy === receipt.modelData.agent ? "Waiting for the password…"
                                  : receipt.modelData.guarded ? "Release" : "Guard"
                            onClicked: guard.setupAgent(receipt.modelData.guarded ? "release" : "guard",
                                                        receipt.modelData.agent)
                        }
                    }
                    Repeater {
                        model: receipt.open ? receipt.modelData.items : []
                        delegate: Text {
                            required property var modelData
                            Layout.fillWidth: true
                            text: modelData.path + "  ·  " + modelData.text
                            color: Theme.muted
                            font.family: Theme.mono
                            font.pixelSize: 11
                            wrapMode: Text.WrapAnywhere
                            textFormat: Text.PlainText
                        }
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                Layout.topMargin: 14
                visible: guard.setup.output !== ""
                text: guard.setup.output
                color: Theme.ink
                font.family: Theme.mono
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                textFormat: Text.PlainText
            }

            Rule { Layout.fillWidth: true; Layout.topMargin: 36 }
            GridLayout {
                Layout.topMargin: 26
                columns: 2
                columnSpacing: 40
                rowSpacing: 14
                Caption { text: "Machine" }
                Text { text: guard.user + " on " + guard.host; color: Theme.ink; font.family: Theme.mono; font.pixelSize: 13; textFormat: Text.PlainText }
                Caption { text: "Policy" }
                Text { text: "/etc/harness-guard/policy.toml · " + guard.policyId; color: Theme.ink; font.family: Theme.mono; font.pixelSize: 13 }
                Caption { text: "Program" }
                Text { text: "/usr/lib/harness-guard"; color: Theme.ink; font.family: Theme.mono; font.pixelSize: 13 }
                Caption { text: "History" }
                Text { text: "~/.local/state/harness-guard-console · 60 days"; color: Theme.ink; font.family: Theme.mono; font.pixelSize: 13 }
                Caption { text: "Keys" }
                Text { text: "Ctrl+1 Overview · Ctrl+2 Activity · Ctrl+3 Integrity · F5 Refresh · Ctrl+Q Quit"; color: Theme.muted; font.family: Theme.mono; font.pixelSize: 12 }
            }
        }
    }
}
