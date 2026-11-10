import QtQuick
import QtQuick.Layouts
import Quickshell
import "pins.js" as Pins

// Who answers in the island, and how. The header below carries the mascot, so the page's own title stays empty.
Page {
    id: pg
    // How to install each one, shown as text to copy. Nothing here runs it.
    readonly property var install: ({
        claude: { cmd: "npm i -g @anthropic-ai/claude-code", more: Tr.t("Or use the official installer from Anthropic.") },
        cursor: { cmd: "curl https://cursor.com/install -fsS | bash", more: "" },
        codex: { cmd: "npm i -g @openai/codex", more: "" }
    })
    Component.onCompleted: Assistant.refresh()

    component Line: RowLayout {
        property string label: ""
        property string hint: ""
        Layout.fillWidth: true; Layout.minimumHeight: 58; spacing: 16
        ColumnLayout {
            Layout.fillWidth: true; spacing: 0
            Tx { text: label; strong: true; Layout.fillWidth: true }
            Tx { visible: !!hint; text: hint; dim: true; size: 13; wrapMode: Text.Wrap; Layout.fillWidth: true }
        }
    }
    // Green and breathing: this one is ready.
    component Pulse: Item {
        implicitWidth: 8; implicitHeight: 8
        Rectangle { id: halo; anchors.fill: parent; radius: 4; color: Theme.good }
        Rectangle { anchors.fill: parent; radius: 4; color: Theme.good }
        ParallelAnimation {
            running: true; loops: Animation.Infinite
            NumberAnimation { target: halo; property: "scale"; from: 1; to: 2.6; duration: 1600; easing.type: Easing.OutCubic }
            NumberAnimation { target: halo; property: "opacity"; from: 0.6; to: 0; duration: 1600 }
        }
    }

    RowLayout {
        Layout.fillWidth: true; spacing: 16
        Lagu { size: 56; mood: Assistant.busy ? Assistant.mood : "idle"; animate: true }
        ColumnLayout {
            Layout.fillWidth: true; spacing: 4
            Tx { text: Tr.t("Assistant"); size: 30; strong: true; Layout.fillWidth: true; Accessible.role: Accessible.Heading; Accessible.name: text }
            Tx { text: Tr.t("Who answers in the island. It uses the login already on this computer."); dim: true; wrapMode: Text.Wrap; Layout.fillWidth: true }
        }
    }

    Rectangle {
        visible: Assistant.providers.length > 0
        Layout.fillWidth: true; Layout.topMargin: 18
        implicitHeight: radios.implicitHeight + 12; radius: 20
        color: Theme.hover
        Accessible.role: Accessible.Grouping
        Accessible.name: Tr.t("Who answers")
        ColumnLayout {
            id: radios
            x: 6; y: 6; width: parent.width - 12; spacing: 0
            Repeater {
                model: Assistant.providers
                ColumnLayout {
                    id: prov
                    required property var modelData
                    required property int index
                    readonly property bool on: Assistant.provider === modelData.id
                    readonly property bool ok: !!modelData.installed
                    readonly property bool needsLogin: ok && modelData.loggedIn === false
                    readonly property var how: pg.install[modelData.id] ?? null
                    readonly property string status: !ok ? Tr.t("Not installed") : needsLogin ? Tr.t("Needs login") : Tr.t("Available")
                    Layout.fillWidth: true; spacing: 0
                    Rectangle { visible: prov.index > 0; Layout.fillWidth: true; Layout.leftMargin: 14; Layout.rightMargin: 14; implicitHeight: 1; color: Theme.line }
                    Rectangle {
                        id: radio
                        readonly property var provider: prov.modelData
                        function pick() { if (prov.ok) Cfg.v.aiProvider = prov.modelData.id }
                        Layout.fillWidth: true; implicitHeight: 64; radius: 14
                        color: prov.on ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.12) : rm.containsMouse && prov.ok ? Theme.hover : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.fast } }
                        border.width: activeFocus ? 2 : 0; border.color: Theme.ink
                        activeFocusOnTab: prov.ok
                        Accessible.role: Accessible.RadioButton
                        Accessible.name: prov.modelData.name + ", " + prov.status
                        Accessible.checked: prov.on
                        Accessible.onPressAction: pick()
                        Keys.onSpacePressed: pick()
                        Keys.onReturnPressed: pick()
                        MouseArea { id: rm; anchors.fill: parent; hoverEnabled: true; enabled: prov.ok; cursorShape: Qt.PointingHandCursor; onClicked: radio.pick() }
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14; spacing: 14
                            Rectangle {
                                implicitWidth: 22; implicitHeight: 22; radius: 11
                                color: "transparent"
                                border.width: 2; border.color: prov.on ? Theme.accent : prov.ok ? Theme.muted : Theme.line
                                Rectangle {
                                    anchors.centerIn: parent; width: 10; height: 10; radius: 5
                                    color: Theme.accent
                                    scale: prov.on ? 1 : 0
                                    Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 2 } }
                                }
                            }
                            Tx { text: prov.modelData.name; size: 16; strong: true; opacity: prov.ok ? 1 : 0.6; Layout.fillWidth: true }
                            Pulse { visible: prov.ok && !prov.needsLogin }
                            Tx { text: prov.status; size: 14; color: prov.ok && !prov.needsLogin ? Theme.good : Theme.muted }
                            Btn { visible: prov.needsLogin; text: Tr.t("Log in"); onClicked: Assistant.login(prov.modelData.id) }
                        }
                    }
                    // How to install it: copy the command into a terminal, then log in there once.
                    ColumnLayout {
                        visible: !prov.ok && !!prov.how
                        Layout.fillWidth: true; Layout.leftMargin: 50; Layout.rightMargin: 14; Layout.bottomMargin: 12
                        spacing: 6
                        Tx { text: Tr.t("To install it, run this in a terminal, then log in there once:"); dim: true; size: 13; wrapMode: Text.Wrap; Layout.fillWidth: true }
                        RowLayout {
                            Layout.fillWidth: true; spacing: 8
                            Rectangle {
                                Layout.fillWidth: true; implicitHeight: 36; radius: 10
                                color: Theme.field
                                border.width: cmd.activeFocus ? 2 : 0; border.color: Theme.accent
                                TextInput {
                                    id: cmd
                                    anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                                    verticalAlignment: TextInput.AlignVCenter
                                    readOnly: true; selectByMouse: true; activeFocusOnTab: true; clip: true
                                    text: prov.how?.cmd ?? ""
                                    color: Theme.ink; selectionColor: Theme.accent; selectedTextColor: Theme.accentInk
                                    font.family: Theme.mono; font.pixelSize: 13
                                    Accessible.role: Accessible.EditableText
                                    Accessible.name: Tr.t("Install command for %1").arg(prov.modelData.name)
                                }
                            }
                            Btn {
                                id: copy
                                property bool done: false
                                icon: done ? "check" : "copy"
                                a11y: Tr.t("Copy")
                                onClicked: { Quickshell.execDetached(["wl-copy", cmd.text]); done = true; copied.restart() }
                                Timer { id: copied; interval: 1500; onTriggered: copy.done = false }
                            }
                        }
                        Tx { visible: !!prov.how?.more; text: prov.how?.more ?? ""; dim: true; size: 13; wrapMode: Text.Wrap; Layout.fillWidth: true }
                    }
                }
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true; Layout.topMargin: 10; spacing: 2
        Line {
            label: Tr.t("Ask before changing files")
            hint: Tr.t("Opening apps and screens never asks.")
            Swt { a11y: Tr.t("Ask before changing files"); checked: Cfg.v.aiAsk; onToggled: Cfg.v.aiAsk = checked }
        }
        Line {
            label: Tr.t("Show in the island")
            Swt { a11y: Tr.t("Show in the island"); checked: Cfg.island.includes("lagu"); onToggled: Cfg.v.island = Pins.set(Cfg.island, "lagu", checked) }
        }
        Line {
            label: Tr.t("Shortcut")
            Rectangle {
                implicitWidth: keyT.implicitWidth + 24; implicitHeight: 32; radius: 10
                color: Theme.raised
                Accessible.role: Accessible.StaticText
                Accessible.name: Tr.t("Shortcut") + ": " + keyT.text
                Tx { id: keyT; anchors.centerIn: parent; text: "Super + A"; mono: true; size: 13 }
            }
        }
    }
}
