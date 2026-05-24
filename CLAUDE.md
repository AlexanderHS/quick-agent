# CLAUDE.md

This file provides guidance to Claude Code and other coding agents when working with this repository.

## Project Overview

quick-agent is a Bash-based interactive launcher that displays a list of repositories, lets the user choose one quickly, changes into that directory, and launches a terminal coding agent.

It generalizes the original quick-claude tool. The core abstraction is: pick repo → cd there → run command.

## Architecture

- **quick-agent.sh**: Main script. It must be sourced, not executed, so that `cd` affects the parent shell before launching the agent. Displays an interactive menu of repos from `$REPOS_DIR`, sorted by recent commit date by default.
- **install.sh**: Detects known agents on PATH, writes `.env`, and adds aliases to `.bashrc` or `.zshrc`.
- **uninstall.sh**: Removes managed aliases from the shell config.
- **.env**: Optional config file to override `REPOS_DIR`, `DEFAULT_AGENT`, or `LAUNCH_COMMAND`.

## Known Agents

Known agent shortcuts intentionally choose low-friction/full-access modes where the CLI supports them:

- `pi` → `pi`
- `claude` → `claude --dangerously-skip-permissions`
- `opencode` / `oc` → `opencode`
- `codex` → `codex --dangerously-bypass-approvals-and-sandbox`
- `gemini` → `gemini -y`

Default aliases installed when binaries exist:

- `w` → pi
- `c` → Claude Code
- `s` → OpenCode
- `x` → Codex
- `g` → Gemini CLI

## Key Implementation Details

- Uses ANSI escape codes for colors and cursor control.
- Hides cursor during menu navigation; restores on exit via trap.
- Type-to-search filters repos by case-insensitive prefix match and auto-selects when narrowed to one match.
- `/` toggles sort between date and name.
- `1-9` quick-selects when not searching.
- Escape clears search first, then exits on second press.
- Git repos show last commit date; non-git directories show `not git`.
- Cross-platform date handling supports GNU and BSD `stat`/`date` variants.
- Scrolling viewport: when the list is taller than `$LINES` minus a 6-line reservation, the menu shows a fixed-height window that follows the cursor. `↑ N more` / `↓ N more` indicators show hidden rows and match counts during search.
- Keep the script dependency-light and portable across personal machines.
