# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-11-10

### Added

- Lagu, the assistant inside Atoll's island: press `Super+A` and the island stretches into a bar to ask about the computer or have it open screens, start focus mode, control music, launch apps and move windows.
- Answers drop below the bar with the steps taken, plus visual cards (ring, bars, buttons that open an Atoll screen or an app) for memory, disk, battery, CPU and network.
- Works through the AI command-line tool already logged in on the computer: Claude Code and Cursor Agent, and OpenAI Codex from its documentation (untested). No API keys.
- Eight animated moods: idle, listening, thinking, working, waiting for you, done, error and sleeping.
- Safety: a short list of read-only and desktop commands runs on its own, anything else asks first; sudo and its relatives are never allowed; secret folders are never read; web pages are fetched only with your OK.
- The Assistant screen in Atoll's control center to choose the tool and whether to ask before changing files.

[Unreleased]: https://github.com/brayanspagnol/lagu/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/brayanspagnol/lagu/releases/tag/v0.1.0
