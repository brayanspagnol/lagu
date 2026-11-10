import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell

// The assistant's bar and conversation, inside Ask's window. The bar grows out of the island; the answer drops below it.
Item {
    id: panel
    property bool shown: false
    property bool settled: false // after the opening: items arriving now drop in one by one, not in a cascade
    // The screen's width, from the window: right after the window shows again its own width can still be 0,
    // and a bar sized from that grew to nothing.
    property real span: 0
    property real islandWidth: 430 // the island on this screen: where the bar starts and ends
    readonly property real barWidth: Math.min(1000, Math.max(width, span) - 80)
    readonly property real listWidth: Math.min(760, barWidth - 40)
    // The visible pieces, for the window's input mask, and the text field.
    readonly property Item barItem: bar
    readonly property Item bodyItem: body
    readonly property Item input: field
    readonly property bool ready: Assistant.providers.some(p => p.installed)
    readonly property var current: Assistant.providers.find(p => p.id === Assistant.provider) ?? null
    property var expanded: ({}) // runs of steps opened past their last three, by key

    function send() {
        const q = field.text.trim()
        if (!q || Assistant.busy || !ready) return
        Assistant.ask(q)
        field.text = ""
        list.stick = true
    }
    // Whatever the answer holds, only two kinds of action: open a screen of the control center, or launch an app by its desktop id.
    function actionsOf(card) {
        const acts = Array.isArray(card?.actions) ? card.actions : []
        return acts.filter(a => a && typeof a.label === "string" && a.label.trim() !== ""
            && (typeof a.page === "string" ? Ui.pages.some(p => p.id === a.page) : typeof a.app === "string" && /^[A-Za-z0-9][A-Za-z0-9._+-]*$/.test(a.app))).slice(0, 3)
    }
    function run(a) {
        if (typeof a.page === "string") Ui.show(a.page) // the control center takes the screen, which closes this
        else { Quickshell.execDetached(["gtk-launch", a.app]); Ui.askOpen = false }
    }
    // The items as drawn: a long run of steps keeps its last three, behind a chip that opens the rest.
    readonly property var view: {
        const items = Assistant.items ?? [], s = Assistant.session, rows = [], map = {}
        const add = r => { rows.push(r); map[r.key] = r }
        let lastDenied = -1
        items.forEach((it, i) => { if (it?.kind === "denied") lastDenied = i })
        for (let i = 0; i < items.length; i++) {
            const kind = items[i]?.kind ?? ""
            if (kind !== "step") { add({ key: s + ":" + i, i, kind, live: i === lastDenied }); continue }
            let end = i
            while (end + 1 < items.length && items[end + 1]?.kind === "step") end++
            const run = s + ":" + i, open = !!expanded[run], extra = end - i + 1 - 3
            if (extra > 0) add({ key: s + ":more" + i, kind: "more", run, count: extra, open })
            for (let j = extra > 0 && !open ? end - 2 : i; j <= end; j++) add({ key: s + ":" + j, i: j, kind: "step", running: Assistant.busy && j === items.length - 1 })
            i = end
        }
        return { rows, map }
    }

    onShownChanged: if (shown) { leave.stop(); grow.restart(); field.forceActiveFocus() } else { grow.stop(); leave.restart() }
    // Opening: the bar appears exactly over the island and cross-fades with it, then grows; the conversation
    // waits until the bar has nearly settled, so nothing outruns its background.
    SequentialAnimation {
        id: grow
        PropertyAction { target: bar; property: "width"; value: panel.islandWidth }
        PropertyAction { target: bar; property: "y"; value: 14 }
        PropertyAction { target: bar; property: "height"; value: 56 }
        ParallelAnimation {
            NumberAnimation { target: bar; property: "opacity"; to: 1; duration: 160; easing.type: Easing.InOutQuad }
            SequentialAnimation {
                PauseAnimation { duration: 60 }
                ParallelAnimation {
                    NumberAnimation { target: bar; property: "width"; to: panel.barWidth; duration: 620; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
                    NumberAnimation { target: bar; property: "y"; to: 12; duration: 400; easing.type: Easing.OutCubic }
                    NumberAnimation { target: bar; property: "height"; to: 60; duration: 400; easing.type: Easing.OutCubic }
                }
            }
            SequentialAnimation {
                PauseAnimation { duration: 300 }
                NumberAnimation { target: barRow; property: "opacity"; to: 1; duration: 240; easing.type: Easing.OutCubic }
            }
            SequentialAnimation {
                PauseAnimation { duration: 520 }
                ParallelAnimation {
                    NumberAnimation { target: body; property: "opacity"; to: 1; duration: 280; easing.type: Easing.OutCubic }
                    NumberAnimation { target: bodyShift; property: "y"; from: -16; to: 0; duration: 420; easing.type: Easing.OutCubic }
                }
            }
        }
        ScriptAction { script: { bar.width = Qt.binding(() => panel.barWidth); panel.settled = true } }
    }
    // Closing, the same way back: the conversation lifts away, the bar shrinks into the island's exact shape,
    // and only then do the two cross-fade (Island.qml waits for it).
    ParallelAnimation {
        id: leave
        NumberAnimation { target: body; property: "opacity"; to: 0; duration: 200; easing.type: Easing.InOutCubic }
        NumberAnimation { target: bodyShift; property: "y"; to: -12; duration: 240; easing.type: Easing.InOutCubic }
        NumberAnimation { target: barRow; property: "opacity"; to: 0; duration: 160; easing.type: Easing.InOutCubic }
        SequentialAnimation {
            PauseAnimation { duration: 60 }
            ParallelAnimation {
                NumberAnimation { target: bar; property: "width"; to: panel.islandWidth; duration: 360; easing.type: Easing.InOutCubic }
                NumberAnimation { target: bar; property: "y"; to: 14; duration: 360; easing.type: Easing.InOutCubic }
                NumberAnimation { target: bar; property: "height"; to: 56; duration: 360; easing.type: Easing.InOutCubic }
            }
        }
        SequentialAnimation {
            PauseAnimation { duration: 400 }
            NumberAnimation { target: bar; property: "opacity"; to: 0; duration: 180; easing.type: Easing.InOutQuad }
        }
    }

    Keys.onEscapePressed: Ui.askOpen = false

    // ── Pieces ──────────────────────────────────────────────────────────────

    // Plain text only, selectable: an answer can quote anything, and none of it may style itself or link out.
    component Body: TextEdit {
        readOnly: true
        selectByMouse: true
        textFormat: TextEdit.PlainText
        wrapMode: TextEdit.Wrap
        color: Theme.ink
        selectionColor: Theme.accent
        selectedTextColor: Theme.accentInk
        font.family: Theme.sans
        font.pixelSize: 16
        Accessible.role: Accessible.StaticText
        Accessible.name: text
    }
    component Spinner: Shape {
        implicitWidth: 16; implicitHeight: 16
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: Theme.accent; strokeWidth: 2.2; fillColor: "transparent"; capStyle: ShapePath.RoundCap
            PathAngleArc { centerX: 8; centerY: 8; radiusX: 6.5; radiusY: 6.5; startAngle: 0; sweepAngle: 270 }
        }
        RotationAnimation on rotation { from: 0; to: 360; duration: 900; loops: Animation.Infinite }
    }
    // A card unfolds from the top: its height opens over its content. The list's entry animation drives reveal.
    component Card: Frost {
        id: card
        default property alias content: inner.data
        property real reveal: 1
        radius: 28
        clip: true
        height: (inner.implicitHeight + 48) * reveal
        ColumnLayout { id: inner; x: 28; y: 24; width: card.width - 56; spacing: 18 }
    }
    component Pill: Btn {
        radius: 22; implicitHeight: 44
        color: variant === "solid" ? (pressed ? Qt.darker(Theme.accent, 1.15) : Theme.accent) : hovered ? Theme.raisedHover : Theme.raised
    }

    component UserBubble: Item {
        id: u
        property var item
        height: bubble.height
        Frost {
            id: bubble
            anchors.right: parent.right
            width: Math.min(u.width * 0.78, said.implicitWidth + 36)
            height: said.implicitHeight + 24
            radius: 22
            Rectangle { anchors.fill: parent; radius: parent.radius; color: Theme.accentSoft }
            Body {
                id: said
                x: 18; y: 12; width: bubble.width - 36
                text: u.item?.text ?? ""
            }
        }
    }

    component Step: Item {
        id: st
        property var item
        property bool running: false
        height: 40
        Frost {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(st.width, stepRow.implicitWidth + 32)
            height: 40; radius: 20
            Accessible.role: Accessible.StaticText
            Accessible.name: stepText.text + (st.item?.detail ? ", " + stepDetail.text : "")
            RowLayout {
                id: stepRow
                anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 18; spacing: 10
                Rectangle {
                    implicitWidth: 28; implicitHeight: 28; radius: 14
                    color: st.running ? Theme.raised : Qt.rgba(Theme.good.r, Theme.good.g, Theme.good.b, 0.18)
                    Ic { anchors.centerIn: parent; visible: !st.running; name: "check"; size: 14; color: Theme.good }
                    Spinner { anchors.centerIn: parent; visible: st.running }
                }
                Tx { id: stepText; text: Tr.t(st.item?.text ?? ""); size: 14; Layout.maximumWidth: implicitWidth }
                Tx {
                    id: stepDetail
                    visible: !!st.item?.detail
                    text: String(st.item?.detail ?? "").replace(/\s+/g, " ").trim()
                    mono: true; dim: true; size: 12
                    Layout.fillWidth: true; Layout.maximumWidth: implicitWidth
                }
            }
        }
    }

    component More: Item {
        id: mo
        property var row
        height: 32
        Rectangle {
            id: chip
            anchors.horizontalCenter: parent.horizontalCenter
            width: moreRow.implicitWidth + 24; height: 32; radius: 16
            color: mm.containsMouse ? Theme.raisedHover : Theme.raised
            border.width: activeFocus ? 2 : 0; border.color: Theme.ink
            activeFocusOnTab: true
            Accessible.role: Accessible.Button
            Accessible.name: moreText.text
            Accessible.onPressAction: toggle()
            Keys.onSpacePressed: toggle()
            Keys.onReturnPressed: toggle()
            function toggle() { panel.expanded = Object.assign({}, panel.expanded, { [mo.row.run]: !mo.row.open }) }
            RowLayout {
                id: moreRow; anchors.centerIn: parent; spacing: 6
                Tx { id: moreText; text: mo.row?.open ? Tr.t("Fewer steps") : Tr.t("%1 steps").arg(mo.row?.count ?? 0); size: 13; dim: true }
                Ic { name: mo.row?.open ? "up" : "down"; size: 14; color: Theme.muted }
            }
            MouseArea { id: mm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: chip.toggle() }
        }
    }

    component Answer: Card {
        id: an
        property var item
        Body { Layout.fillWidth: true; text: an.item?.text ?? "" }
    }

    component Visual: Card {
        id: vis
        property var item
        readonly property var c: item?.card ?? ({})
        readonly property var acts: panel.actionsOf(c)
        readonly property var bars: (Array.isArray(c.bars) ? c.bars : []).slice(0, 6)
        readonly property real ringValue: clamp(c.ring?.value)
        // A label with a number ("57%", "9 GB") is the ring's big text; a word ("memory") goes under the percentage.
        readonly property string ringLabel: c.ring?.label ?? ""
        readonly property bool ringSays: /\d/.test(ringLabel)
        property real grow: 0 // ring and bars fill once the card has opened
        function clamp(v) { return Math.max(0, Math.min(1, Number(v) || 0)) }
        function tone(v) { return v > 0.6 ? Theme.warn : Theme.accent }
        readonly property bool open: reveal > 0.4 // ring, bars and buttons start once the card has mostly unfolded
        SequentialAnimation on grow {
            running: vis.open
            PauseAnimation { duration: 150 }
            NumberAnimation { from: 0; to: 1; duration: 1100; easing.type: Easing.OutCubic }
        }
        Body { visible: !!vis.item?.text; Layout.fillWidth: true; text: vis.item?.text ?? "" }
        RowLayout {
            Layout.fillWidth: true; spacing: 24
            Item {
                visible: !!vis.c.ring
                implicitWidth: 116; implicitHeight: 116
                Accessible.role: Accessible.ProgressBar
                Accessible.name: vis.ringSays ? vis.ringLabel : vis.ringLabel + " " + Math.round(vis.ringValue * 100) + "%"
                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: Theme.raised; strokeWidth: 12; fillColor: "transparent"
                        PathAngleArc { centerX: 58; centerY: 58; radiusX: 48; radiusY: 48; startAngle: -90; sweepAngle: 360 }
                    }
                    ShapePath {
                        strokeColor: vis.tone(vis.ringValue); strokeWidth: 12; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                        PathAngleArc { centerX: 58; centerY: 58; radiusX: 48; radiusY: 48; startAngle: -90; sweepAngle: 360 * vis.ringValue * vis.grow }
                    }
                }
                Column {
                    anchors.centerIn: parent
                    opacity: Math.min(1, vis.grow * 3)
                    Tx { anchors.horizontalCenter: parent.horizontalCenter; width: Math.min(implicitWidth, 90); text: vis.ringSays ? vis.ringLabel : Math.round(vis.ringValue * vis.grow * 100) + "%"; size: vis.ringSays && vis.ringLabel.length > 4 ? 20 : 28; strong: true; horizontalAlignment: Text.AlignHCenter }
                    Tx { anchors.horizontalCenter: parent.horizontalCenter; visible: !vis.ringSays && !!text; width: Math.min(implicitWidth, 84); text: vis.ringLabel; size: 12; dim: true; horizontalAlignment: Text.AlignHCenter }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 6
                // The title, with a light that passes over it now and then.
                Item {
                    Layout.fillWidth: true; implicitHeight: title.implicitHeight
                    Tx {
                        id: title; width: parent.width
                        text: vis.c.title ?? ""; size: 28; strong: true; wrapMode: Text.Wrap; maximumLineCount: 3
                        Accessible.role: Accessible.Heading; Accessible.name: text
                    }
                    Item {
                        id: band
                        property real sweep: -90
                        x: sweep; width: 90; height: parent.height
                        clip: true
                        Tx {
                            x: -band.x; width: title.width
                            text: title.text; size: 28; strong: true; wrapMode: Text.Wrap; maximumLineCount: 3
                            color: Qt.tint(Theme.ink, Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.7))
                            Accessible.ignored: true
                        }
                        SequentialAnimation on sweep {
                            running: panel.shown; loops: Animation.Infinite
                            PauseAnimation { duration: 1500 }
                            NumberAnimation { from: -90; to: title.width; duration: 1500; easing.type: Easing.InOutSine }
                            PauseAnimation { duration: 2500 }
                        }
                    }
                }
                Tx { visible: !!vis.c.subtitle; text: vis.c.subtitle ?? ""; dim: true; wrapMode: Text.Wrap; Layout.fillWidth: true }
            }
        }
        ColumnLayout {
            visible: vis.bars.length > 0
            Layout.fillWidth: true; spacing: 11
            Repeater {
                model: vis.bars
                RowLayout {
                    id: meter
                    required property var modelData
                    required property int index
                    readonly property real value: vis.clamp(modelData?.value)
                    property real fill: 0
                    SequentialAnimation on fill {
                        running: vis.open
                        PauseAnimation { duration: 250 + meter.index * 110 }
                        NumberAnimation { from: 0; to: 1; duration: 700; easing.type: Easing.OutCubic }
                    }
                    Layout.fillWidth: true; spacing: 14
                    Accessible.role: Accessible.StaticText
                    Accessible.name: (modelData?.label ?? "") + ", " + (modelData?.text ?? "")
                    Tx { text: meter.modelData?.label ?? ""; strong: true; Layout.preferredWidth: 170 }
                    Item {
                        Layout.fillWidth: true; implicitHeight: 10
                        Rectangle { anchors.fill: parent; radius: 5; color: Theme.raised }
                        Rectangle {
                            visible: meter.fill > 0 && meter.value > 0
                            width: Math.max(10, parent.width * meter.value * meter.fill); height: 10; radius: 5
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0; color: Qt.darker(vis.tone(meter.value), 1.25) }
                                GradientStop { position: 1; color: vis.tone(meter.value) }
                            }
                        }
                    }
                    Tx { text: meter.modelData?.text ?? ""; strong: true; horizontalAlignment: Text.AlignRight; Layout.preferredWidth: 80 }
                }
            }
        }
        Flow {
            visible: vis.acts.length > 0
            Layout.fillWidth: true; spacing: 10
            Repeater {
                model: vis.acts
                Pill {
                    required property var modelData
                    required property int index
                    readonly property var action: modelData
                    text: modelData.label
                    variant: index === 0 ? "solid" : "quiet"
                    onClicked: panel.run(modelData)
                    transform: Translate { NumberAnimation on y { running: vis.open; from: 10; to: 0; duration: 400; easing.type: Easing.OutCubic } }
                }
            }
        }
    }

    component Denied: Card {
        id: dn
        property var item
        property bool live: false
        readonly property var asks: (Array.isArray(item?.denials) ? item.denials : []).slice(0, 4)
        function said(v) { return v === undefined || v === null ? "" : typeof v === "string" ? v : JSON.stringify(v) }
        RowLayout {
            Layout.fillWidth: true; spacing: 12
            Ic { name: "alert"; size: 22; color: Theme.warn }
            Tx { text: Tr.t("Lagu needs your OK"); size: 18; strong: true; Layout.fillWidth: true; Accessible.role: Accessible.Heading; Accessible.name: text }
        }
        Body { visible: !!dn.item?.text; Layout.fillWidth: true; text: dn.item?.text ?? "" }
        Repeater {
            model: dn.asks
            Rectangle {
                id: ask
                required property var modelData
                readonly property string tool: typeof modelData === "string" ? modelData : dn.said(modelData?.tool)
                readonly property string input: typeof modelData === "string" ? "" : dn.said(modelData?.input).replace(/\s+/g, " ")
                Layout.fillWidth: true; implicitHeight: askCol.implicitHeight + 20; radius: 14
                color: Theme.raised
                Accessible.role: Accessible.StaticText
                Accessible.name: tool + " " + input
                ColumnLayout {
                    id: askCol
                    x: 14; y: 10; width: parent.width - 28; spacing: 2
                    Tx { text: ask.tool; mono: true; strong: true; size: 13; Layout.fillWidth: true }
                    Tx { visible: !!ask.input; text: ask.input; mono: true; dim: true; size: 13; Layout.fillWidth: true }
                }
            }
        }
        RowLayout {
            visible: dn.live
            spacing: 10
            Pill { text: Tr.t("Allow"); variant: "solid"; onClicked: Assistant.allow() }
            Pill { text: Tr.t("Deny"); variant: "quiet"; onClicked: Assistant.deny() }
        }
    }

    component Failure: Card {
        id: fl
        property var item
        RowLayout {
            Layout.fillWidth: true; spacing: 12
            Ic { name: "alert"; size: 22; color: Theme.danger }
            Body { Layout.fillWidth: true; text: fl.item?.text || Tr.t("Something went wrong.") }
        }
        Tx { visible: !!fl.item?.detail; text: String(fl.item?.detail ?? ""); mono: true; dim: true; size: 12; wrapMode: Text.Wrap; maximumLineCount: 4; Layout.fillWidth: true }
        Pill { visible: !!fl.item?.login; text: Tr.t("Log in"); variant: "solid"; onClicked: Assistant.login(Assistant.provider) }
    }

    // ── The bar, where the island was ───────────────────────────────────────

    Frost {
        id: bar
        anchors.horizontalCenter: parent.horizontalCenter
        y: 12
        width: 430; height: 60; radius: height / 2
        opacity: 0
        MouseArea { anchors.fill: parent; onClicked: field.forceActiveFocus() }
        RowLayout {
            id: barRow
            anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 8
            spacing: 10
            opacity: 0
            Lagu {
                size: 46
                mood: !panel.ready ? "sleeping" : !Assistant.busy && field.activeFocus && field.text ? "listening" : Assistant.mood
                animate: panel.shown
            }
            TextInput {
                id: field
                Layout.fillWidth: true
                readOnly: !panel.ready
                color: Theme.ink; selectionColor: Theme.accent; selectedTextColor: Theme.accentInk
                font.family: Theme.sans; font.pixelSize: 17
                clip: true
                focus: true
                Accessible.role: Accessible.EditableText
                Accessible.name: Tr.t("Ask the assistant")
                Component.onCompleted: forceActiveFocus()
                Keys.onReturnPressed: panel.send()
                Keys.onEnterPressed: panel.send()
                Keys.onEscapePressed: Ui.askOpen = false
                Tx {
                    visible: !field.text; size: 17; dim: true; anchors.verticalCenter: parent.verticalCenter
                    width: field.width
                    text: panel.ready ? Tr.t("Ask anything about this computer…") : Tr.t("No assistant installed yet")
                }
            }
            // Who answers; opens the Assistant screen.
            Rectangle {
                id: who
                visible: !!panel.current
                implicitWidth: whoRow.implicitWidth + 20; implicitHeight: 30; radius: 15
                color: wm.containsMouse ? Theme.raisedHover : Theme.raised
                border.width: activeFocus ? 2 : 0; border.color: Theme.ink
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: Tr.t("Answered by %1").arg(panel.current?.name ?? "")
                Accessible.onPressAction: Ui.show("ia")
                Keys.onSpacePressed: Ui.show("ia")
                Keys.onReturnPressed: Ui.show("ia")
                RowLayout {
                    id: whoRow; anchors.centerIn: parent; spacing: 6
                    Rectangle { implicitWidth: 8; implicitHeight: 8; radius: 4; color: panel.current?.installed ? Theme.good : Theme.muted }
                    Tx { text: panel.current?.name ?? ""; size: 13; dim: true }
                }
                MouseArea { id: wm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Ui.show("ia") }
            }
            // Send, or stop while it works.
            Rectangle {
                id: go
                visible: panel.ready
                readonly property bool stopping: Assistant.busy
                readonly property bool can: stopping || (panel.ready && field.text.trim() !== "")
                implicitWidth: 44; implicitHeight: 44; radius: 22
                color: stopping ? (gm.containsMouse ? Theme.raisedHover : Theme.raised) : gm.pressed ? Qt.darker(Theme.accent, 1.15) : Theme.accent
                opacity: can ? 1 : 0.45
                Behavior on color { ColorAnimation { duration: Theme.fast } }
                Behavior on opacity { NumberAnimation { duration: Theme.fast } }
                border.width: activeFocus ? 2 : 0; border.color: Theme.ink
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: stopping ? Tr.t("Stop") : Tr.t("Send")
                Accessible.onPressAction: press()
                Keys.onSpacePressed: press()
                Keys.onReturnPressed: press()
                function press() { if (stopping) Assistant.stop(); else panel.send() }
                Ic { anchors.centerIn: parent; name: go.stopping ? "stop" : "arrowUp"; filled: go.stopping; size: 18; color: go.stopping ? Theme.ink : Theme.accentInk }
                MouseArea { id: gm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: go.press() }
            }
        }
    }

    // ── Below it: the conversation, or how to get an assistant ──────────────

    Column {
        id: body
        anchors.horizontalCenter: parent.horizontalCenter
        y: bar.y + bar.height + 12
        width: panel.listWidth
        spacing: 10
        opacity: 0
        transform: Translate { id: bodyShift; y: -12 }

        Card {
            visible: !panel.ready
            width: parent.width
            SequentialAnimation on reveal {
                PauseAnimation { duration: 260 }
                NumberAnimation { from: 0; to: 1; duration: 620; easing.type: Easing.OutQuint }
            }
            RowLayout {
                Layout.fillWidth: true; spacing: 18
                Lagu { size: 56; mood: "sleeping"; animate: panel.shown }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 4
                    Tx { text: Tr.t("No assistant installed yet"); size: 20; strong: true; Layout.fillWidth: true; Accessible.role: Accessible.Heading; Accessible.name: text }
                    Tx {
                        text: Tr.t("Lagu answers with the Claude Code, Cursor or Codex command line already logged in on this computer. No API keys.")
                        dim: true; wrapMode: Text.Wrap; Layout.fillWidth: true
                    }
                }
            }
            Pill { text: Tr.t("Set up the assistant"); variant: "solid"; onClicked: Ui.show("ia") }
        }

        ListView {
            id: list
            width: parent.width
            height: Math.min(contentHeight, Math.max(120, panel.height - body.y - foot.height - 60))
            visible: count > 0
            clip: true
            spacing: 10
            cacheBuffer: 4000
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height
            Accessible.role: Accessible.List
            Accessible.name: Tr.t("Conversation")
            ScrollBar.vertical: ScrollBar { policy: list.contentHeight > list.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff; width: 6 }
            // Follows the newest item, unless scrolled up to read.
            property bool stick: true
            onMovementEnded: stick = atYEnd
            onContentHeightChanged: if (stick) positionViewAtEnd()
            onHeightChanged: if (stick) positionViewAtEnd()
            model: ScriptModel { values: panel.view.rows; objectProp: "key" }
            delegate: Item {
                id: d
                required property var modelData
                required property int index
                // A kept entry's modelData goes stale, so the fresh row and item come from the key.
                readonly property var row: panel.view.map[modelData.key] ?? modelData
                readonly property var item: Assistant.items[row.i] ?? ({})
                property real unfold: 0
                width: ListView.view.width
                height: ld.item ? ld.item.height : 0
                opacity: 0
                transform: Translate { id: drop }
                Component.onCompleted: enter.start()
                SequentialAnimation {
                    id: enter
                    PauseAnimation { duration: panel.settled ? 0 : 280 + Math.min(d.index, 10) * 50 }
                    ParallelAnimation {
                        NumberAnimation { target: d; property: "opacity"; to: 1; duration: 220 }
                        NumberAnimation { target: drop; property: "y"; from: -18; to: 0; duration: 460; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
                        NumberAnimation { target: d; property: "scale"; from: 0.94; to: 1; duration: 460; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
                        NumberAnimation { target: d; property: "unfold"; from: 0; to: 1; duration: 620; easing.type: Easing.OutQuint }
                    }
                }
                Loader {
                    id: ld
                    sourceComponent: ({ user: userC, step: stepC, more: moreC, text: textC, card: cardC, denied: deniedC, error: errorC })[d.row.kind] ?? null
                }
                Component { id: userC; UserBubble { width: d.width; item: d.item } }
                Component { id: stepC; Step { width: d.width; item: d.item; running: d.row.running ?? false } }
                Component { id: moreC; More { width: d.width; row: d.row } }
                Component { id: textC; Answer { width: d.width; item: d.item; reveal: d.unfold } }
                Component { id: cardC; Visual { width: d.width; item: d.item; reveal: d.unfold } }
                Component { id: deniedC; Denied { width: d.width; item: d.item; reveal: d.unfold; live: (Assistant.pending?.length ?? 0) > 0 && (d.row.live ?? false) } }
                Component { id: errorC; Failure { width: d.width; item: d.item; reveal: d.unfold } }
            }
        }

        // A fresh start, once there is something to clear.
        Frost {
            id: foot
            visible: panel.ready && (Assistant.items?.length ?? 0) > 0
            anchors.horizontalCenter: parent.horizontalCenter
            width: footRow.implicitWidth + 28; height: 40; radius: 20
            RowLayout {
                id: footRow
                anchors.centerIn: parent; spacing: 12
                Btn {
                    variant: "quiet"; implicitHeight: 30; radius: 15
                    icon: "plus"; text: Tr.t("New conversation")
                    onClicked: { Assistant.reset(); panel.expanded = {}; field.forceActiveFocus() }
                }
            }
        }
    }
}
