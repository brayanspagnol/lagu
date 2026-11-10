import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// The assistant, grown out of the island. Super+A or the island's mascot.
// Built once and kept hidden: creating the window and its panel on the click made the opening stutter.
Scope {
    id: ask
    // Outlives Ui.askOpen by the closing animation; the window must exist to play it.
    property bool alive: false
    readonly property bool isOpen: Ui.askOpen
    onIsOpenChanged: {
        if (isOpen) { closing.stop(); alive = true; grabLater.restart() }
        else { grabLater.stop(); grabReady = false; closing.restart() }
    }
    // The click-outside grab waits for the window to be on screen again: armed at once, it was cleared at once,
    // and the assistant closed right after opening.
    property bool grabReady: false
    Timer { id: grabLater; interval: 250; onTriggered: ask.grabReady = true }
    Timer { id: closing; interval: 620; onTriggered: ask.alive = false } // a little longer than AskPanel's leave

    PanelWindow {
        id: win
        visible: ask.alive && !!Ui.screen
        screen: Quickshell.screens.includes(Ui.askScreen) ? Ui.askScreen : Ui.screen
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: Ui.askOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.namespace: "atoll-ask"
        color: "transparent"
        // The bar and the conversation only, so the rest of the screen stays clickable.
        mask: Region {
            Region { item: panel.barItem }
            Region { item: panel.bodyItem }
        }
        // A click anywhere else closes it.
        HyprlandFocusGrab {
            active: Ui.askOpen && win.visible && ask.grabReady
            windows: [win]
            onCleared: Ui.askOpen = false
        }
        AskPanel {
            id: panel
            anchors.fill: parent
            span: win.screen ? win.screen.width : 0
            islandWidth: Ui.islandWidths[win.screen?.name ?? ""] ?? 430
            Component.onCompleted: shown = Qt.binding(() => Ui.askOpen)
        }
    }
}
