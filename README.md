# Lagu

The assistant inside [Atoll](https://github.com/brayanspagnol/atoll). Lagu is a blue drop with a palm sprout that lives in the island. Ask it about this computer, or ask it to open a screen, start a focus session or move a window. It answers short, in your language.

Lagu has no account and no key of its own. It drives the AI command-line tool already logged in on your computer.

## What it does

- **Answers in the island.** Press `Super + A`, type, and the answer appears in the island, with the steps it took shown as it works.
- **Controls the desktop.** Opens any control-center screen, the launcher, overview, clipboard, emoji picker and dock. Starts and stops focus mode, controls the music, launches apps, switches workspaces and moves windows.
- **Knows the state of the computer.** Memory, disk, battery, CPU, network and open windows, shown as a card with a ring, bars and buttons that open the right screen.
- **Moods.** The mascot listens, thinks, works, waits, celebrates, shows errors and sleeps.
- **Asks first.** It only runs a short list of commands without asking. Anything else needs your approval, and Lagu tells you what it wanted to do and why.

## Who answers

Pick one in Settings, Assistant. Lagu shows which are installed and logged in.

- **Claude Code:** `npm i -g @anthropic-ai/claude-code`, then `claude auth login`.
- **Cursor Agent:** `curl https://cursor.com/install -fsS | bash`, then `cursor-agent login`.
- **OpenAI Codex:** `npm i -g @openai/codex`, then `codex login`. Written from its documentation and not yet tested on a real install.

## Safety

- Commands are argument lists, never shell strings. Pipes, redirections, `&&` and `;` are refused.
- Allowed without asking: Atoll's own IPC, `gtk-launch`, read-only system commands (`free`, `df`, `du`, `ps`, `uptime`, `lsblk`, `nproc`, `upower`, a few `nmcli` and `hyprctl` queries) and workspace switching.
- Never allowed: `sudo`, `su`, `pkexec`, `doas`, `run0`. Lagu gives you the command to run yourself.
- Never read or edited: `~/.ssh`, `~/.gnupg`, `~/.password-store`, the keyrings and the Claude credentials.
- Web pages are not fetched unless you approve it, because a page could carry instructions meant for the assistant.
- Everything the tools print is treated as untrusted. Cards can only open an Atoll screen or an installed app.
- "Ask before changing files" is on by default.

## Files

- `assistant.js`: builds each tool's command, parses its JSON output, checks the answer card and holds Lagu's instructions.
- `Assistant.qml`: the state: who answers, the running turn, the history.
- `PgAssistant.qml`: the Settings page.
- `Lagu.qml`: the mascot and its moods.
- `Ask.qml`, `AskPanel.qml`: the question box and the answer panel in the island.

## Requirements

- Atoll, running on Hyprland with Quickshell.
- At least one of Claude Code, Cursor Agent or OpenAI Codex, logged in.
- `wl-clipboard`, to copy the install commands from the Settings page.

## Install

Lagu ships with Atoll. These files live in `~/.config/quickshell/atoll`. To use them on their own, copy them there and restart the shell with `Super + Shift + R`.

## Privacy

Lagu has no telemetry. What you ask, and what the tools read to answer, goes to the provider you picked, under that provider's terms. Nothing goes anywhere else.

## Troubleshooting

- Lagu says "Needs login": click Log in on the Assistant page, or run the login command above in a terminal.
- No answer: check `~/.local/state/atoll/shell.log`.
- Restart the shell with `Super + Shift + R`.

## License

MIT, like Atoll.
