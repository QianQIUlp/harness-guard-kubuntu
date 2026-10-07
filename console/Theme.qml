// Paper, ink and one red, after me.qiu.works. Follows the system's light/dark scheme.
pragma Singleton
import QtQuick

QtObject {
    property int scheme: Qt.styleHints.colorScheme
    readonly property bool dark: scheme === Qt.ColorScheme.Dark

    readonly property color paper: dark ? "#1a1c1a" : "#eeede7"
    readonly property color raised: dark ? "#222522" : "#f5f4ef"
    readonly property color ink: dark ? "#e8e6de" : "#252825"
    readonly property color muted: dark ? "#8e9086" : "#73756b"
    readonly property color line: dark ? "#33e8e6de" : "#30252825"
    readonly property color faint: dark ? "#14e8e6de" : "#14252825"
    readonly property color red: dark ? "#ff5b3f" : "#e83d27"
    readonly property color redWash: dark ? "#26ff5b3f" : "#18e83d27"
    readonly property color bright: "#fffaf2"

    // An agent's state is a fill, so it reads before any word: red is open (needs you),
    // ink is running (active, held), paper is idle (held, at rest).
    function stateOf(agent, procs) {
        return !agent || !agent.guarded || !agent.enforcing ? "open" : procs > 0 ? "running" : "idle"
    }
    function fill(state) { return state === "open" ? red : state === "running" ? ink : "transparent" }
    function fore(state) { return state === "open" ? bright : state === "running" ? paper : ink }
    function soft(state) { return Qt.alpha(fore(state), state === "idle" ? 0.55 : 0.62) }

    readonly property string sans: "IBM Plex Sans"
    readonly property string serif: "IBM Plex Serif"
    readonly property string mono: "IBM Plex Mono"

    readonly property int gutter: 40
    readonly property int quick: 160
    readonly property int calm: 420
}
