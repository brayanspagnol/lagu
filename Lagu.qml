import QtQuick
import QtQuick.Shapes

// Lagu, the assistant's mascot: a blue drop with a palm sprout. Each mood changes the eyes, the sprout and what floats around.
// Drawn in the design's own coordinates (viewBox -30 -24 220 190) and scaled to fit. Every motion is a function of one clock,
// so animate: false (or a hidden item) leaves the still pose and nothing runs.
Item {
    id: root
    property string mood: "idle" // idle, listening, thinking, working, waiting, done, error, sleeping
    property real size: 64
    property bool animate: true
    implicitWidth: size; implicitHeight: size
    clip: true
    Accessible.role: Accessible.Graphic
    Accessible.name: "Lagu"

    readonly property var moods: ["idle", "listening", "thinking", "working", "waiting", "done", "error", "sleeping"]
    readonly property string face: moods.includes(mood) ? mood : "idle"
    readonly property bool tiny: Math.min(width, height) <= 32 // small extras hidden, and a tighter box around what is left
    readonly property bool live: animate && visible
    property real time: 0
    FrameAnimation { running: root.live; onTriggered: root.time += frameTime }

    // CSS-like keyframes: frames are [[0..1, value], ...] over period seconds. Still, it returns rest (or the first value).
    function k(period, delay, frames, ease, rest) {
        if (!live) return rest ?? frames[0][1]
        let p = ((time - delay) / period) % 1
        if (p < 0) p += 1
        for (let i = 1; i < frames.length; i++) {
            if (p > frames[i][0]) continue
            const a = frames[i - 1], b = frames[i]
            let f = b[0] > a[0] ? (p - a[0]) / (b[0] - a[0]) : 1
            f = ease === "linear" ? f : ease === "out" ? 1 - (1 - f) * (1 - f) : ease === "in" ? f * f : f * f * (3 - 2 * f)
            return a[1] + (b[1] - a[1]) * f
        }
        return frames[frames.length - 1][1]
    }

    readonly property color ink: "#0E1826"
    readonly property color sky: "#8CC8F5"
    readonly property string bodyD: "M80 44 C112 44 132 66 132 96 C132 126 110 140 80 140 C50 140 28 126 28 96 C28 66 48 44 80 44Z"
    readonly property string stemD: "M80 48 C80 38 79 32 78 26"
    readonly property string leftD: "M78 28 C66 16 52 18 46 26 C58 26 68 28 78 30Z"
    readonly property string rightD: "M79 28 C90 14 106 16 112 24 C100 25 90 28 79 31Z"
    readonly property string perkStemD: "M80 46 L80 22"
    readonly property string perkLeftD: "M80 24 C70 8 56 8 50 14 C60 16 70 20 80 26Z"
    readonly property string perkRightD: "M80 24 C90 8 104 8 110 14 C100 16 90 20 80 26Z"

    component Body: Shape {
        id: bd
        property string d: root.bodyD
        property real from: 44
        property color c1: "#A9DAFA"
        property color c2: "#4E97D1"
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "transparent"
            fillGradient: LinearGradient { y1: bd.from; y2: 140; GradientStop { position: 0; color: bd.c1 } GradientStop { position: 1; color: bd.c2 } }
            PathSvg { path: bd.d }
        }
    }
    component Sprout: Shape {
        id: sp
        property string stem: root.stemD
        property string leaf1: root.leftD
        property string leaf2: root.rightD
        property color stemColor: "#3E8F6E"
        property color leftColor: "#8FD9B6"
        property color rightColor: "#6CC79E"
        preferredRendererType: Shape.CurveRenderer
        ShapePath { strokeColor: sp.stemColor; strokeWidth: 5; fillColor: "transparent"; capStyle: ShapePath.RoundCap; PathSvg { path: sp.stem } }
        ShapePath { strokeColor: "transparent"; fillColor: sp.leftColor; PathSvg { path: sp.leaf1 } }
        ShapePath { strokeColor: "transparent"; fillColor: sp.rightColor; PathSvg { path: sp.leaf2 } }
    }
    component Line: Shape {
        id: ln
        property string d
        property color c: root.ink
        property real w: 3
        preferredRendererType: Shape.CurveRenderer
        ShapePath { strokeColor: ln.c; strokeWidth: ln.w; fillColor: "transparent"; capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin; PathSvg { path: ln.d } }
    }
    component Blob: Shape {
        id: bl
        property string d
        property color c
        preferredRendererType: Shape.CurveRenderer
        ShapePath { strokeColor: "transparent"; fillColor: bl.c; PathSvg { path: bl.d } }
    }
    component Dot: Rectangle {
        property real cx
        property real cy
        property real r
        x: cx - r; y: cy - r; width: 2 * r; height: 2 * r; radius: r
    }
    component Eye: Rectangle { width: 12; radius: 6; color: root.ink }
    component Mark: Text { // a glyph whose baseline sits at base, centered on cx like SVG's text-anchor: middle
        property real cx
        property real base
        x: cx - width / 2; y: base - baselineOffset
        font.family: "Instrument Sans"; font.weight: Font.Bold
        color: root.ink
        Accessible.ignored: true
    }
    // Something that fades in, drifts and fades out on a loop (sound arcs, confetti, rain, z's). Still, it simply shows.
    component Drift: Item {
        id: dr
        property real period: 1
        property real delay: 0
        property string ease: "inout"
        property var fade: [[0, 0], [0.3, 1], [1, 0]]
        property real fromX: 0
        property real dx: 0
        property real dy: 0
        property real fromY: 0
        property real spin: 0
        property real grow: 1
        property real shrink: 1
        property real cx: 0
        property real cy: 0
        visible: !root.tiny
        opacity: root.k(period, delay, fade, ease, 1)
        transform: [
            Rotation { origin.x: dr.cx; origin.y: dr.cy; angle: root.k(dr.period, dr.delay, [[0, 0], [1, dr.spin]], dr.ease, 0) },
            Scale { origin.x: dr.cx; origin.y: dr.cy; xScale: root.k(dr.period, dr.delay, [[0, dr.shrink], [1, dr.grow]], dr.ease, 1); yScale: xScale },
            Translate {
                x: root.k(dr.period, dr.delay, [[0, dr.fromX], [1, dr.dx]], dr.ease, 0)
                y: root.k(dr.period, dr.delay, [[0, dr.fromY], [1, dr.dy]], dr.ease, 0)
            }
        ]
    }

    // The design's box, fitted into the item keeping its aspect.
    readonly property var box: tiny ? [20, -26, 166, 170] : [-30, -24, 220, 190]
    readonly property real s: Math.min(width / box[2], height / box[3])
    Item {
        x: (root.width - root.box[2] * root.s) / 2 - root.box[0] * root.s
        y: (root.height - root.box[3] * root.s) / 2 - root.box[1] * root.s
        transform: Scale { xScale: root.s; yScale: root.s }
        Repeater {
            model: root.moods
            Loader {
                id: slot
                required property string modelData
                readonly property bool shown: root.face === modelData
                opacity: shown ? 1 : 0
                active: shown || opacity > 0
                Behavior on opacity { enabled: root.live; NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
                transform: Scale { origin.x: 80; origin.y: 140; xScale: 0.9 + 0.1 * slot.opacity; yScale: xScale }
                sourceComponent: root.parts[modelData]
            }
        }
    }
    readonly property var parts: ({ idle: idlePose, listening: listeningPose, thinking: thinkingPose, working: workingPose, waiting: waitingPose, done: donePose, error: errorPose, sleeping: sleepingPose })

    Component {
        id: idlePose
        Item {
            transform: Scale { origin.x: 80; origin.y: 140; xScale: root.k(3, 0, [[0, 1], [0.5, 1.03], [1, 1]]); yScale: root.k(3, 0, [[0, 1], [0.5, 0.97], [1, 1]]) }
            Sprout { transform: Rotation { origin.x: 79; origin.y: 48; angle: root.k(2.8, 0, [[0, -6], [0.5, 8], [1, -6]], "inout", 0) } }
            Body { }
            Item {
                transform: [
                    Scale { origin.x: 80; origin.y: 90; yScale: root.k(4.2, 0, [[0, 1], [0.9, 1], [0.94, 0.1], [1, 1]]) },
                    Translate { x: root.k(6, 0, [[0, 0], [0.4, 0], [0.5, -4], [0.62, -4], [0.72, 4], [0.88, 4], [1, 0]]) }
                ]
                Eye { x: 58; y: 80; height: 20 }
                Eye { x: 90; y: 80; height: 20 }
            }
        }
    }
    Component {
        id: listeningPose
        Item {
            Repeater {
                model: [["M-14 70 Q-22 88 -14 106", 0], ["M-4 74 Q-10 88 -4 102", 0.5], ["M-24 64 Q-34 88 -24 112", 1]]
                Drift {
                    required property var modelData
                    period: 1.5; delay: modelData[1]; ease: "out"; fade: [[0, 0], [0.4, 1], [1, 0]]; fromX: -12; dx: 10
                    Line { d: modelData[0]; c: root.sky; w: 4 }
                }
            }
            Item {
                transform: [
                    Translate { y: root.k(1.2, 0, [[0, 0], [0.5, -4], [1, 0]]) },
                    Rotation { origin.x: 80; origin.y: 140; angle: -6 }
                ]
                Sprout { stem: root.perkStemD; leaf1: root.perkLeftD; leaf2: root.perkRightD }
                Body { c1: "#BDE3FC"; c2: "#5AA3DB" }
                Dot { cx: 63; cy: 88; r: 10; color: root.ink }
                Dot { cx: 97; cy: 88; r: 10; color: root.ink }
            }
        }
    }
    Component {
        id: thinkingPose
        Item {
            Item {
                transform: Translate { y: root.k(2.4, 0, [[0, 0], [0.5, -5], [1, 0]]) }
                Repeater {
                    model: [[122, 40, 4], [134, 26, 6], [156, 2, 14], [172, -6, 11], [144, -8, 10], [166, 8, 10]]
                    Dot { required property var modelData; cx: modelData[0]; cy: modelData[1]; r: modelData[2]; color: "#E6EDF4" }
                }
                Mark {
                    id: ask
                    cx: 158; base: 9; text: "?"; font.pixelSize: 22
                    transform: Rotation { origin.x: ask.width / 2; origin.y: ask.baselineOffset - 3; angle: root.k(1.6, 0, [[0, -12], [0.5, 12], [1, -12]], "inout", 0) }
                }
            }
            Item {
                transform: Scale { origin.x: 80; origin.y: 140; xScale: root.k(3, 0, [[0, 1], [0.5, 1.03], [1, 1]]); yScale: root.k(3, 0, [[0, 1], [0.5, 0.97], [1, 1]]) }
                Sprout { transform: Rotation { origin.x: 79; origin.y: 48; angle: root.k(2.8, 0, [[0, -6], [0.5, 8], [1, -6]], "inout", 0) } }
                Body { }
                Line { d: "M55 70 L69 70 M88 66 Q96 60 105 65" }
                Eye { x: 56; y: 75; height: 18 }
                Eye { x: 89; y: 72; height: 18 }
            }
        }
    }
    Component {
        id: workingPose
        Item {
            Repeater {
                model: [[140, 70, 22, 16, 4, "#8CC8F5", 0], [150, 96, 18, 13, 3, "#8FD9B6", 0.6], [136, 40, 16, 12, 3, "#F5D38C", 1.2]]
                Drift {
                    required property var modelData
                    period: 1.8; delay: modelData[6]; ease: "out"; dx: 12; fromY: 8; dy: -26
                    Rectangle { x: modelData[0]; y: modelData[1]; width: modelData[2]; height: modelData[3]; radius: modelData[4]; color: modelData[5] }
                }
            }
            Line { d: "M-18 80 H-4 M-24 96 H-6 M-18 112 H-4"; c: root.sky; w: 3.5; opacity: 0.7; visible: !root.tiny }
            Item {
                transform: Translate { y: root.k(0.32, 0, [[0, 0], [0.5, 5], [1, 0]]) }
                Sprout { transform: Scale { origin.x: 79; xScale: root.k(0.42, 0, [[0, 1], [0.5, -1], [1, 1]], "linear") } }
                Body { }
                Line { d: "M54 76 L70 81 M106 76 L90 81"; w: 3.2 }
                Eye { x: 58; y: 84; height: 13 }
                Eye { x: 90; y: 84; height: 13 }
            }
        }
    }
    Component {
        id: waitingPose
        Item {
            Item {
                transform: Translate { y: root.k(2.4, 0, [[0, 0], [0.5, -5], [1, 0]]) }
                Rectangle { x: 140; y: -6; width: 38; height: 38; radius: 12; color: "#F5D38C" }
                Blob { d: "M150 32 L146 42 L158 32Z"; c: "#F5D38C" }
                Mark { cx: 159; base: 22; text: "!"; font.pixelSize: 26 }
            }
            Item {
                transform: Translate { y: root.k(1.2, 0, [[0, 0], [0.5, -4], [1, 0]]) }
                Sprout { stem: root.perkStemD; leaf1: root.perkLeftD; leaf2: root.perkRightD }
                Body { }
                Line { d: "M54 72 Q62 65 70 69 M90 69 Q98 65 106 72" }
                Dot { cx: 64; cy: 88; r: 8.5; color: root.ink }
                Dot { cx: 96; cy: 88; r: 8.5; color: root.ink }
            }
        }
    }
    Component {
        id: donePose
        Item {
            Repeater {
                model: [[-8, 10, 8, 5, "#F5D38C", 0], [20, -14, 7, 5, "#FF9F87", 0.4], [136, -12, 8, 5, "#8FD9B6", 0.8], [164, 16, 7, 5, "#CFE9FC", 1.2], [150, 40, 6, 4, "#F5D38C", 0.4], [-16, 46, 6, 4, "#8FD9B6", 1.2]]
                Drift {
                    required property var modelData
                    period: 1.6; delay: modelData[5]; fade: [[0, 0], [0.2, 1], [1, 0]]; fromY: -12; dy: 46; spin: 240
                    cx: modelData[0] + modelData[2] / 2; cy: modelData[1] + modelData[3] / 2
                    Rectangle { x: modelData[0]; y: modelData[1]; width: modelData[2]; height: modelData[3]; radius: 1.5; color: modelData[4] }
                }
            }
            Item {
                transform: [
                    Scale {
                        origin.x: 80; origin.y: 140
                        xScale: root.k(1.3, 0, [[0, 1.06], [0.15, 0.95], [0.45, 0.98], [0.75, 1.07], [1, 1.06]], "inout", 1)
                        yScale: root.k(1.3, 0, [[0, 0.94], [0.15, 1.06], [0.45, 1.02], [0.75, 0.93], [1, 0.94]], "inout", 1)
                    },
                    Translate { y: root.k(1.3, 0, [[0, 0], [0.15, 0], [0.45, -24], [0.75, 0], [1, 0]]) }
                ]
                Sprout {
                    stem: "M80 48 C80 38 79 32 78 24"
                    leaf1: "M78 30 C66 18 52 20 46 28 C58 28 68 30 78 32Z"
                    leaf2: "M79 30 C90 16 106 18 112 26 C100 27 90 30 79 33Z"
                }
                Item {
                    transform: Scale { origin.x: 78; origin.y: 19.5; xScale: root.k(1.3, 0, [[0, 0.3], [0.3, 1], [0.8, 1], [1, 0.3]], "inout", 1); yScale: xScale }
                    Repeater {
                        model: [[78, 12], [86, 18], [83, 27], [73, 27], [70, 18]]
                        Dot { required property var modelData; cx: modelData[0]; cy: modelData[1]; r: 5.5; color: "#FFD1DC" }
                    }
                    Dot { cx: 78; cy: 20; r: 4.5; color: "#F5D38C" }
                }
                Body { c1: "#BDE3FC"; c2: "#5AA3DB" }
                Line { d: "M56 92 Q64 80 72 92 M88 92 Q96 80 104 92"; w: 4.5 }
            }
        }
    }
    Component {
        id: errorPose
        Item {
            Dot { cx: 66; cy: -4; r: 12; color: "#8C9AA8" }
            Dot { cx: 82; cy: -10; r: 15; color: "#8C9AA8" }
            Dot { cx: 98; cy: -4; r: 12; color: "#8C9AA8" }
            Rectangle { x: 56; y: -4; width: 52; height: 12; radius: 6; color: "#8C9AA8" }
            Repeater {
                model: [["M66 14 L64 22", 0], ["M82 14 L80 22", 0.33], ["M98 14 L96 22", 0.66]]
                Drift {
                    required property var modelData
                    delay: modelData[1]; ease: "linear"; fade: [[0, 0], [0.2, 1], [1, 0]]; dy: 28
                    Line { d: modelData[0]; c: root.sky }
                }
            }
            Sprout {
                transform: Rotation { origin.x: 79; origin.y: 48; angle: 38 }
                stemColor: "#5E8A77"; leftColor: "transparent"; rightColor: "#8DB3A2"
            }
            Drift {
                period: 2.6; ease: "in"; fade: [[0, 1], [1, 0]]; dx: 16; dy: 74; spin: 130; cx: 55; cy: 40
                Blob { d: "M44 40 C52 34 62 36 66 42 C58 44 50 44 44 40Z"; c: "#9CC4B2" }
            }
            Body { d: "M80 48 C112 48 132 70 132 99 C132 127 110 140 80 140 C50 140 28 127 28 99 C28 70 48 48 80 48Z"; from: 48; c1: "#C3D0DB"; c2: "#7F93A6" }
            Line { d: "M54 78 L69 73 M106 78 L91 73" }
            Eye { x: 58; y: 83; height: 17 }
            Eye { x: 90; y: 83; height: 17 }
            Drift {
                period: 2.4; ease: "in"; fade: [[0, 0], [0.3, 0], [0.45, 1], [1, 0]]
                transform: Translate { y: root.k(2.4, 0, [[0, 0], [0.3, 0], [1, 18]], "in", 0) }
                Blob { d: "M58 102 Q62 110 58 113 Q54 110 58 102Z"; c: root.sky }
            }
        }
    }
    Component {
        id: sleepingPose
        Item {
            Repeater {
                model: [[118, 44, 16, "z", 0], [130, 30, 22, "z", 1], [144, 14, 28, "Z", 2]]
                Drift {
                    required property var modelData
                    period: 3; delay: modelData[4]; dx: 18; dy: -32; shrink: 0.6; grow: 1.25
                    cx: modelData[0] + modelData[2] * 0.3; cy: modelData[1] - modelData[2] * 0.35
                    Mark { x: modelData[0]; base: modelData[1]; text: modelData[3]; font.pixelSize: modelData[2]; color: "#CFE9FC" }
                }
            }
            Item {
                transform: Scale { origin.x: 80; origin.y: 140; xScale: root.k(4, 0, [[0, 1], [0.5, 1.04], [1, 1]]); yScale: root.k(4, 0, [[0, 1], [0.5, 0.96], [1, 1]]) }
                Sprout { transform: Rotation { origin.x: 79; origin.y: 48; angle: -28 } }
                Body { d: "M80 46 C114 46 134 68 134 98 C134 127 111 140 80 140 C49 140 26 127 26 98 C26 68 46 46 80 46Z"; from: 46; c1: "#93C3E8"; c2: "#3F7DB3" }
                Line { d: "M56 90 Q63 97 70 90 M90 90 Q97 97 104 90"; w: 3.5 }
            }
        }
    }
}
