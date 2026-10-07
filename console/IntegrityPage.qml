// The installed check as a picture: one dot per check, failures spelled out.
import QtQuick
import QtQuick.Controls.Basic as Q
import QtQuick.Layouts

Item {
    id: page
    property var nav
    readonly property var lines: guard.checkLines.filter(l => l.kind === "ok" || l.kind === "fail")
    readonly property int failed: lines.filter(l => l.kind === "fail").length
    readonly property bool running: guard.checkExit === -2

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

            Caption { text: "Integrity · " + (page.running ? "running" : guard.checkTime ? "last run " + guard.checkTime : "not run") }

            RowLayout {
                Layout.topMargin: 26
                Layout.fillWidth: true
                spacing: 30
                Text {
                    Layout.fillWidth: true
                    textFormat: Text.StyledText
                    color: Theme.ink
                    font.family: Theme.sans
                    font.pixelSize: 52
                    font.weight: Font.Medium
                    font.letterSpacing: -1.8
                    lineHeight: 1.04
                    wrapMode: Text.WordWrap
                    text: page.running ? "Checking<br><font face='" + Theme.serif + "'><i>" + page.lines.length + " so far…</i></font>"
                        : guard.checkExit < 0 ? "Not checked yet."
                        : page.failed === 0 ? "Every check<br><font face='" + Theme.serif + "'><i>holds.</i></font>"
                        : page.failed + " of " + page.lines.length + " checks<br><font face='" + Theme.serif
                          + "' color='" + Theme.red + "'><i>fail.</i></font>"
                }
                RoundAction {
                    glyph: "↻"
                    text: page.running ? "Checking…" : "Run again"
                    note: "As " + guard.user + ", from outside the guards"
                    enabled: !page.running
                    onClicked: guard.runCheck()
                }
            }

            // Past runs, oldest first: a mark per run, red where something failed.
            RowLayout {
                Layout.topMargin: 34
                spacing: 16
                visible: guard.checkHistory.length > 0
                Caption { text: "Runs" }
                Row {
                    spacing: 4
                    Repeater {
                        model: guard.checkHistory
                        Rectangle {
                            required property var modelData
                            width: 8
                            height: 22
                            radius: 1
                            color: modelData.failed ? Theme.red : Theme.ink
                            opacity: modelData.failed ? 1 : 0.7
                            MouseArea { id: runHover; anchors.fill: parent; hoverEnabled: true }
                            Q.ToolTip.visible: runHover.containsMouse
                            Q.ToolTip.text: Qt.formatDateTime(new Date(modelData.t * 1000), "d MMM HH:mm") + " · "
                                            + (modelData.failed ? modelData.failed + " of " + modelData.total + " failed" : "all " + modelData.total + " passed")
                        }
                    }
                }
            }

            // One row per section: its name, then a dot per check.
            Rule { Layout.fillWidth: true; Layout.topMargin: 30 }
            Repeater {
                model: guard.checkSections
                ColumnLayout {
                    id: section
                    required property var modelData
                    readonly property var checks: modelData.items.filter(l => l.kind === "ok" || l.kind === "fail")
                    readonly property var notes: modelData.items.filter(l => l.kind === "info")
                    readonly property var fails: checks.filter(l => l.kind === "fail")
                    Layout.fillWidth: true
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 22
                        spacing: 22
                        Text {
                            Layout.preferredWidth: 260
                            text: (section.modelData.title || "checks").replace(/^./, c => c.toUpperCase())
                            color: Theme.ink
                            font.family: Theme.sans
                            font.pixelSize: 15
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                        }
                        Flow {
                            Layout.fillWidth: true
                            spacing: 7
                            Repeater {
                                model: section.checks
                                Item {
                                    required property var modelData
                                    width: 11
                                    height: 11
                                    Dot { anchors.centerIn: parent; width: 9; height: 9; good: parent.modelData.kind === "ok" }
                                    MouseArea { id: hover; anchors.fill: parent; hoverEnabled: true }
                                    Q.ToolTip.visible: hover.containsMouse
                                    Q.ToolTip.text: modelData.text.replace(/^(ok|FAIL) +/, "")
                                }
                            }
                        }
                        Caption {
                            text: section.checks.length ? (section.checks.length - section.fails.length) + "/" + section.checks.length : ""
                            color: section.fails.length ? Theme.red : Theme.muted
                        }
                    }
                    Repeater {
                        model: section.fails
                        Text {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.leftMargin: 282
                            text: modelData.text.replace(/^FAIL +/, "")
                            color: Theme.red
                            font.family: Theme.mono
                            font.pixelSize: 13
                            wrapMode: Text.Wrap
                            textFormat: Text.PlainText
                        }
                    }
                    Repeater {
                        model: section.notes
                        Text {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.leftMargin: 282
                            // check.sh prints `N profile="P" operation="O" ... name="F"`
                            text: modelData.text.replace(/^(\d+) .*?profile="([^"]+)".*?operation="([^"]+)"(?:.*?name="([^"]*)")?.*$/,
                                                         (m, n, p, o, f) => n.padStart(4) + "×  " + p + "  " + o + "  " + (f || ""))
                            color: Theme.muted
                            font.family: Theme.mono
                            font.pixelSize: 12
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                        }
                    }
                    Rule { Layout.fillWidth: true; Layout.topMargin: 12; color: Theme.faint }
                }
            }
        }
    }
}
