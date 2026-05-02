# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

quick-claude is a bash-based interactive launcher that displays a list of repositories sorted by last commit date, allowing quick navigation and immediate launch of Claude Code in the selected repository.

## Architecture

- **quick-claude.sh**: Main script that must be sourced (not executed) to allow `cd` to affect the parent shell. Displays an interactive arrow-key menu of repos from `$REPOS_DIR`, sorted by most recent commit, then runs `claude` in the selected directory.
- **install.sh**: Adds a shell alias (default: `w`) to the user's `.bashrc` or `.zshrc`
- **uninstall.sh**: Removes the alias from the shell config
- **.env**: Optional config file to override `REPOS_DIR` (default: `~/repos`)

## Key Implementation Details

- Uses ANSI escape codes for colors and cursor control
- Hides cursor during menu navigation, restores on exit via trap
- **Type-to-search**: letters filter repos by case-insensitive prefix match; auto-selects when narrowed to one match
- `/` toggles sort between date (default) and name; `1-9` quick-select when not searching
- Escape clears search first, then exits on second press
- Git repos show last commit date; non-git directories show "not git"
- Cross-platform date handling (GNU and BSD `stat`/`date` variants)
- **Scrolling viewport**: when the list is taller than `$LINES` minus a 6-line reservation (4-line header + breathing room), the menu shows a fixed-height window that follows the cursor. `↑ N more` / `↓ N more` indicators (with match counts during search) show what's hidden. Cursor-redraw math uses `displayed_rows` (viewport size + 2 indicator lines when overflowing) instead of `total`.
