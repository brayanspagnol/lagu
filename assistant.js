.pragma library
// Lagu, the assistant: drives the AI command-line tools already logged in on this computer (Claude Code, Cursor Agent,
// OpenAI Codex) in their headless JSON modes. Commands are argv arrays, never shell strings. Everything the tools print
// is untrusted: parse() turns a line into plain events and never throws, card() lets the answer show numbers and buttons
// that can only open an Atoll screen or an installed app.

// Control-center screens, as in Ui.qml's pages. Assistant.qml passes the live list; this is the fallback.
const pages = ["som", "rede", "bt", "perf", "cal", "clima", "avisos", "monitor", "ajustes", "visual", "atalhos", "apps", "regras", "backup", "energia", "sobre"]
// Step labels, English keys for Tr.t.
const labels = ["Running a command", "Controlling the desktop", "Reading a file", "Editing a file", "Searching files", "Searching the web", "Reading a web page", "Using a tool"]

const workspaces = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
// What Claude may run without asking. Each one reads, or moves things on screen; none writes or deletes data or starts an
// arbitrary program. A rule ending in :* also allows extra arguments; the others match only exactly. Claude Code still
// refuses redirections, pipes and chains unless every part is allowed (seen: "df -h > out.txt" is denied under df:*).
// hyprctl is exact-only: `hyprctl dispatch` takes Lua in Hyprland 0.56, and `eval`, `keyword` and `dispatch exec` run anything.
// nmcli is exact-only too: with other arguments it deletes connections and switches radios off.
const commands = [
    "qs -c atoll ipc call ui:*", "qs -c atoll ipc call focus:*", "qs -c atoll ipc call media:*",
    "gtk-launch:*",
    "df:*", "free:*", "du:*", "ps:*", "uptime:*", "lsblk:*", "nproc", "upower -e", "upower -i:*",
    "nmcli -t device status", "nmcli -t connection show --active", "nmcli -t device wifi list", "nmcli -t general status",
    "hyprctl -j clients", "hyprctl -j activewindow", "hyprctl -j workspaces", "hyprctl -j activeworkspace", "hyprctl -j monitors"
].concat(workspaces.map(n => `hyprctl dispatch 'hl.dsp.focus({ workspace = ${n} })'`),
    workspaces.map(n => `hyprctl dispatch 'hl.dsp.window.move({ workspace = ${n} })'`))
// No WebFetch by default: a fetched page could carry instructions to send home files out. A denial still lets the user allow it once.
const allowed = ["Read", "Glob", "Grep", "WebSearch"].concat(commands.map(c => "Bash(" + c + ")"))
// Never, not even once: deny rules beat any allow. Secrets stay unread even though Read is allowed.
const secrets = ["~/.ssh/**", "~/.gnupg/**", "~/.password-store/**", "~/.local/share/keyrings/**", "~/.claude/.credentials.json"]
const disallowed = ["sudo", "su", "pkexec", "doas", "run0"].map(c => `Bash(${c}:*)`)
    .concat(secrets.map(p => `Read(${p})`), secrets.map(p => `Edit(${p})`))
// A spec the person may approve for one turn: a file or web tool, or one exact command. "*" is a wildcard in Claude's
// rules, so a command with one could match far more than what was shown; it can only be run by the person.
const elevate = /^\s*(sudo|su|pkexec|doas|run0)(\s|$)/
function allowable(spec) {
    if (typeof spec !== "string") return false
    if (/^(Write|Edit|NotebookEdit|Read|Glob|Grep|WebSearch|WebFetch)$/.test(spec)) return true
    const m = /^Bash\((.*)\)$/.exec(spec)
    return !!m && m[1].length > 0 && m[1].length <= 500 && !/[*\u0000-\u001f\u007f]/.test(m[1]) && !elevate.test(m[1])
}

const sessionOk = s => typeof s === "string" && /^[A-Za-z0-9_-]{1,128}$/.test(s)
// The system text goes in front of the first message for the tools without a flag for it.
const first = (o, sys) => o.session ? o.prompt : sys + "\n\n---\n\n" + o.prompt
// o: { prompt, session, allow: [spec], ask: bool, system }. ask false lets Claude edit files without asking.
function argv(provider, o) {
    o = o || {}
    const prompt = String(o.prompt ?? "")
    const sys = typeof o.system === "string" ? o.system : system()
    const resume = sessionOk(o.session) ? o.session : ""
    const opt = Object.assign({}, o, { prompt, session: resume })
    if (provider === "claude") {
        const extra = (Array.isArray(o.allow) ? o.allow : []).filter(allowable)
        // --restricted ignores the person's own Claude settings (their allow rules, hooks, default mode) and keeps file
        // tools inside the working directories; --tools names what it would otherwise remove.
        return ["claude", "-p", "--output-format", "stream-json", "--verbose",
            "--restricted", "--tools", "Bash,Read,Glob,Grep,WebSearch,WebFetch,Write,Edit", "--strict-mcp-config",
            "--add-dir", "/usr/share/applications",
            "--permission-mode", o.ask === false ? "acceptEdits" : "dontAsk", "--permission-prompts", "none",
            "--allowedTools"].concat(allowed, extra, ["--disallowedTools"], disallowed,
            ["--append-system-prompt", sys], resume ? ["--resume", resume] : [], ["--", prompt])
    }
    // Cursor has no per-run allow list: ask mode is read-only; agent mode edits files and runs only the commands the
    // person allowed in Cursor's own settings. Never --force, which runs every command.
    if (provider === "cursor")
        return ["cursor-agent", "-p", "--output-format", "stream-json", "--trust"].concat(o.ask === false ? [] : ["--mode", "ask"],
            resume ? ["--resume", resume] : [], ["--", first(opt, sys)])
    // shortcut: codex is unverified, written from its docs (codex exec --json, read-only sandbox); test it on a real install.
    if (provider === "codex")
        return ["codex", "exec", "--json", "--skip-git-repo-check", "--sandbox", o.ask === false ? "workspace-write" : "read-only"]
            .concat(resume ? ["resume", resume] : [], ["--", first(opt, sys)])
    return []
}
// The login command, run by the person in a terminal.
function loginArgs(provider) {
    return { claude: ["claude", "auth", "login"], cursor: ["cursor-agent", "login"], codex: ["codex", "login"] }[provider] ?? []
}

const isObject = v => !!v && typeof v === "object" && !Array.isArray(v)
const str = v => typeof v === "string" ? v : ""
// One line of plain text for a label's detail: no control characters, capped.
const oneLine = (v, max) => str(v).replace(/[\u0000-\u001f\u007f-\u009f]+/g, " ").trim().slice(0, max || 200)
const clean = (v, max) => str(v).replace(/[\u0000-\u0008\u000b-\u001f\u007f-\u009f]/g, "").slice(0, max)
const base = p => oneLine(str(p).replace(/\/+$/, "").split("/").pop())
const loginRe = /not logged in|please run \/login|authentication required|agent login|codex login|invalid api key/i
const desktopRe = /^(qs -c atoll ipc |gtk-launch |hyprctl )/
function command(cmd) { return { kind: "step", label: desktopRe.test(str(cmd).trim()) ? "Controlling the desktop" : "Running a command", detail: oneLine(cmd) } }
function step(label, detail) { return { kind: "step", label, detail: oneLine(detail) } }

// A Claude tool call as a step.
function claudeStep(name, input) {
    const i = isObject(input) ? input : {}
    switch (name) {
    case "Bash": return command(i.command)
    case "Read": return step("Reading a file", base(i.file_path))
    case "Write": case "Edit": case "MultiEdit": case "NotebookEdit": return step("Editing a file", base(i.file_path ?? i.notebook_path))
    case "Glob": case "Grep": return step("Searching files", i.pattern)
    case "WebSearch": return step("Searching the web", i.query)
    case "WebFetch": return step("Reading a web page", i.url)
    default: return step("Using a tool", name)
    }
}
// Claude's permission_denials, as { tool, input, spec }; spec is "" when it cannot be allowed from here.
function denials(list) {
    const out = []
    for (const d of Array.isArray(list) ? list : []) {
        if (!isObject(d) || typeof d.tool_name !== "string" || out.length >= 10) continue
        const tool = oneLine(d.tool_name, 60), i = isObject(d.tool_input) ? d.tool_input : {}
        const bash = tool === "Bash" && typeof i.command === "string"
        const spec = bash ? "Bash(" + i.command + ")" : tool
        const input = bash ? clean(i.command, 500) : oneLine(i.file_path ?? i.url ?? i.query ?? i.pattern ?? "", 300)
        if (!out.some(o => o.tool === tool && o.input === input)) out.push({ tool, input, spec: allowable(spec) ? spec : "" })
    }
    return out
}
function error(text) { const t = clean(text, 500).trim(); return { kind: "error", text: t, login: loginRe.test(t) } }
// The text of a message's content blocks.
const texts = content => (Array.isArray(content) ? content : []).filter(b => isObject(b) && b.type === "text" && typeof b.text === "string").map(b => b.text).join("")

function parseClaude(d) {
    if (d.type === "system" && d.subtype === "init") return sessionOk(d.session_id) ? [{ kind: "session", id: d.session_id }] : []
    if (d.type === "assistant" && isObject(d.message)) {
        // A failed request comes as a made-up message too; the result line says the same as an error.
        if (d.error || d.isApiErrorMessage || d.is_api_error_message || d.parent_tool_use_id) return []
        const out = []
        for (const b of Array.isArray(d.message.content) ? d.message.content : []) {
            if (!isObject(b)) continue
            if (b.type === "text" && typeof b.text === "string" && b.text.trim()) out.push({ kind: "text", text: clean(b.text, 20000) })
            if (b.type === "tool_use" && typeof b.name === "string") out.push(claudeStep(b.name, b.input))
        }
        return out
    }
    if (d.type === "result") {
        if (d.is_error === true || (typeof d.subtype === "string" && d.subtype.startsWith("error"))) return [error(str(d.result) || (Array.isArray(d.errors) ? d.errors.filter(e => typeof e === "string").join(" ") : "") || d.subtype)]
        return [{ kind: "done", text: clean(d.result, 20000), denials: denials(d.permission_denials) }]
    }
    return []
}
// Cursor's tool calls: one key such as readToolCall with args. shellToolCall's shape is from Cursor's docs, not seen here.
function cursorStep(call) {
    const key = Object.keys(isObject(call) ? call : {}).find(k => /ToolCall$|^function$/.test(k))
    if (!key) return null
    const v = isObject(call[key]) ? call[key] : {}, a = isObject(v.args) ? v.args : {}
    switch (key) {
    case "shellToolCall": return command(a.command)
    case "readToolCall": return step("Reading a file", base(a.path))
    case "writeToolCall": case "editToolCall": case "deleteToolCall": return step("Editing a file", base(a.path))
    case "grepToolCall": case "globToolCall": case "lsToolCall": return step("Searching files", a.pattern ?? a.globPattern ?? base(a.path))
    case "webSearchToolCall": return step("Searching the web", a.searchTerm ?? a.query)
    case "webFetchToolCall": return step("Reading a web page", a.url)
    default: return step("Using a tool", key === "function" ? v.name : key.replace(/ToolCall$/, ""))
    }
}
function parseCursor(d) {
    if (d.type === "system" && d.subtype === "init") return sessionOk(d.session_id) ? [{ kind: "session", id: d.session_id }] : []
    if (d.type === "assistant" && isObject(d.message)) { const t = texts(d.message.content); return t.trim() ? [{ kind: "text", text: clean(t, 20000) }] : [] }
    if (d.type === "tool_call" && d.subtype === "started") { const s = cursorStep(d.tool_call); return s ? [s] : [] }
    if (d.type === "result") return d.is_error === true ? [error(str(d.result) || str(d.error) || "error")] : [{ kind: "done", text: clean(d.result, 20000), denials: [] }]
    if (d.type === "error") return [error(str(d.message) || str(d.error))]
    return []
}
// shortcut: Codex's event names are from its docs (thread.started, item.*, turn.completed/failed, error), not seen here.
function parseCodex(d) {
    const item = isObject(d.item) ? d.item : {}
    if (d.type === "thread.started") return sessionOk(d.thread_id) ? [{ kind: "session", id: d.thread_id }] : []
    if (d.type === "item.started" && item.type === "command_execution") return [command(item.command)]
    if (d.type === "item.started" && item.type === "web_search") return [step("Searching the web", item.query)]
    if (d.type === "item.started" && item.type === "file_change") return [step("Editing a file", "")]
    if (d.type === "item.completed" && item.type === "agent_message" && str(item.text).trim()) return [{ kind: "text", text: clean(item.text, 20000) }]
    if (d.type === "turn.completed") return [{ kind: "done", text: "", denials: [] }]
    if (d.type === "turn.failed") return [error(str(isObject(d.error) ? d.error.message : d.error) || "error")]
    if (d.type === "error") return [error(str(d.message) || "error")]
    return []
}
// One line of a tool's JSON output to zero or more events. Anything unexpected gives none.
function parse(provider, line) {
    if (typeof line !== "string" || line.length > 4000000) return []
    let d
    try { d = JSON.parse(line) } catch (e) { return [] }
    if (!isObject(d) || typeof d.type !== "string") return []
    try {
        if (provider === "claude") return parseClaude(d)
        if (provider === "cursor") return parseCursor(d)
        if (provider === "codex") return parseCodex(d)
    } catch (e) {}
    return []
}
// A tool that exited non-zero, from what it said on stderr (Cursor says it is not logged in only there).
function failure(stderr) {
    const lines = str(stderr).split("\n").map(l => l.trim()).filter(l => l)
    const e = error(lines.slice(-3).join(" "))
    e.login = e.login || loginRe.test(str(stderr))
    return e
}

// One ```atoll-card {json}``` block from the answer, checked field by field; the text comes back without any card block.
const cardRe = /```atoll-card[ \t]*\r?\n?([\s\S]*?)```/g
const unit = v => typeof v === "number" && isFinite(v) && v >= 0 && v <= 1
const label = (v, max) => oneLine(v, max)
function card(text, ids) {
    const all = str(text)
    const found = cardRe.exec(all); cardRe.lastIndex = 0
    const rest = all.replace(cardRe, "").replace(/\n{3,}/g, "\n\n").trim()
    let c = null
    try { c = found ? JSON.parse(found[1]) : null } catch (e) {}
    if (!isObject(c) || !label(c.title, 80)) return { text: rest, card: null }
    const known = Array.isArray(ids) ? ids : pages
    const out = { title: label(c.title, 80), subtitle: label(c.subtitle, 160), ring: null, bars: [], actions: [] }
    if (isObject(c.ring) && unit(c.ring.value)) out.ring = { value: c.ring.value, label: label(c.ring.label, 20) }
    for (const b of Array.isArray(c.bars) ? c.bars : []) {
        if (out.bars.length < 6 && isObject(b) && label(b.label, 40) && unit(b.value)) out.bars.push({ label: label(b.label, 40), value: b.value, text: label(b.text, 20) })
    }
    for (const a of Array.isArray(c.actions) ? c.actions : []) {
        if (out.actions.length >= 3 || !isObject(a) || !label(a.label, 40)) continue
        if (typeof a.page === "string" && known.includes(a.page)) out.actions.push({ label: label(a.label, 40), page: a.page })
        else if (a.page === undefined && typeof a.app === "string" && a.app.length <= 120 && /^[A-Za-z0-9][A-Za-z0-9._+-]*$/.test(a.app)) out.actions.push({ label: label(a.label, 40), app: a.app })
    }
    return { text: rest, card: out }
}

// The instructions added to the tool's own system prompt.
function system(ids) {
    const p = Array.isArray(ids) ? ids : pages
    return `You are Lagu, the assistant inside Atoll, the desktop shell of this computer (Hyprland on Linux).
Answer in the user's language, short and direct, in plain text: no Markdown tables, headings or images.

You can control the desktop with these commands only, each run alone and exactly as written (no pipes, redirection, && or ;):
- A control-center screen: qs -c atoll ipc call ui toggle <page>, with page one of: ${p.join(", ")} (som sound, rede internet, bt Bluetooth, perf performance, cal calendar, clima weather, avisos notifications, monitor displays, ajustes settings, visual personalization, atalhos shortcuts, apps default apps, regras window rules, backup, energia power, sobre about).
- Atoll: qs -c atoll ipc call ui launcher, ui overview, ui clipboard, ui emoji, ui dock, ui close. Focus mode: qs -c atoll ipc call focus start <minutes> (25, 50, 60, or 0 until stopped) and qs -c atoll ipc call focus stop. Music: qs -c atoll ipc call media toggle, media next, media prev.
- An app: gtk-launch <desktop-id>, such as gtk-launch firefox. The ids are the .desktop file names in /usr/share/applications and ~/.local/share/applications.
- Workspaces: hyprctl dispatch 'hl.dsp.focus({ workspace = 2 })' to go to one, hyprctl dispatch 'hl.dsp.window.move({ workspace = 2 })' to move the active window there (1 to 10). Windows: hyprctl -j clients, hyprctl -j activewindow, hyprctl -j workspaces, hyprctl -j activeworkspace, hyprctl -j monitors.
- This computer: free -h, df -h, du, ps, uptime, nproc, lsblk, upower -e and upower -i <device> (battery), nmcli -t device status, nmcli -t connection show --active, nmcli -t device wifi list, nmcli -t general status.
Anything else needs the user's approval. If a tool is denied, say in one sentence what you wanted to do and why, and stop: the user can approve it.
Never use sudo, su or pkexec: give the user the exact command to run in a terminal instead.
Never say something was done unless its command succeeded.

When you answer about this computer's state (memory, disk, battery, CPU, network), add one card with the numbers at the end:
\`\`\`atoll-card
{"title": "Memory", "subtitle": "9.1 of 16 GB in use", "ring": {"value": 0.57, "label": "57%"}, "bars": [{"label": "Swap", "value": 0.1, "text": "0.8 GB"}], "actions": [{"label": "Performance", "page": "perf"}]}
\`\`\`
title up to 80 characters, subtitle 160; ring and bar values from 0 to 1; up to 6 bars and 3 actions. An action opens a screen ("page") or an app ("app": a desktop id), nothing else.`
}
