// How the console itself behaves: tray, notifications, starting at login.
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
                Text { text: "/usr/local/lib/harness-guard-console"; color: Theme.ink; font.family: Theme.mono; font.pixelSize: 13 }
                Caption { text: "History" }
                Text { text: "~/.local/state/harness-guard-console · 60 days"; color: Theme.ink; font.family: Theme.mono; font.pixelSize: 13 }
                Caption { text: "Keys" }
                Text { text: "Ctrl+1 Overview · Ctrl+2 Activity · Ctrl+3 Integrity · F5 Refresh · Ctrl+Q Quit"; color: Theme.muted; font.family: Theme.mono; font.pixelSize: 12 }
            }
        }
    }
}
