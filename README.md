# quick-agent

Quick launcher to jump into a repo and start coding with your preferred terminal agent.

It is the agent-neutral successor to `quick-claude`: pick a repo fast, `cd` into it, then launch `pi`, Claude Code, OpenCode, Codex, Gemini, or any custom command.

## Install

```bash
git clone git@github.com:AlexanderHS/quick-agent.git
cd quick-agent
./install.sh
```

The installer:

- asks for your repos directory, default `~/repos`
- detects known agents on `PATH`
- offers sensible aliases
- installs aliases into `~/.bashrc` or `~/.zshrc`
- writes `.env`

Default alias suggestions:

| Alias | Agent | Command |
|---|---|---|
| `w` | pi | `pi` |
| `c` | Claude Code | `claude --dangerously-skip-permissions` |
| `s` | OpenCode | `opencode` |
| `x` | Codex | `codex --dangerously-bypass-approvals-and-sandbox` |
| `g` | Gemini CLI | `gemini -y` |

Then restart your shell or run:

```bash
source ~/.bashrc   # or ~/.zshrc
```

## Usage

```bash
w              # pick repo, launch pi by default
c              # pick repo, launch Claude Code dangerously
s              # pick repo, launch OpenCode
x              # pick repo, launch Codex dangerously
```

You can also pass an agent or arbitrary command:

```bash
source quick-agent.sh pi
source quick-agent.sh claude
source quick-agent.sh codex
source quick-agent.sh nvim
source quick-agent.sh bash
```

Known agent shortcuts expand to their preferred low-friction command:

```bash
claude -> claude --dangerously-skip-permissions
codex  -> codex --dangerously-bypass-approvals-and-sandbox
gemini -> gemini -y
pi     -> pi
```

## Menu keys

| Key | Action |
|-----|--------|
| a-z | Type to search; auto-selects on single match |
| ↑/↓ | Navigate; skips between matches when searching |
| 1-9 | Quick select when not searching |
| / | Toggle sort: date / name |
| Backspace | Delete last search character |
| Enter | Confirm selection |
| Esc | Clear search, or exit if not searching |

## Configuration

Copy `.env.example` to `.env` or run `./install.sh`.

```bash
REPOS_DIR="$HOME/repos"
DEFAULT_AGENT="pi"
```

For a custom default command:

```bash
LAUNCH_COMMAND="pi --model sonnet:high"
```

## Uninstall

```bash
./uninstall.sh
```

## Requirements

- Bash
- Git, for commit-date sorting
- One or more terminal coding agents, e.g. `pi`, `claude`, `opencode`, `codex`, `gemini`
