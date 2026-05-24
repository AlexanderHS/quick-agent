#!/bin/bash
# Uninstall quick-agent aliases

set -euo pipefail

if [[ -n "${ZSH_VERSION:-}" ]] || [[ "${SHELL:-}" == */zsh ]]; then
    RC_FILE="$HOME/.zshrc"
else
    RC_FILE="$HOME/.bashrc"
fi

MARKER_START="# quick-agent aliases start"
MARKER_END="# quick-agent aliases end"

if [[ ! -f "$RC_FILE" ]]; then
    echo "$RC_FILE not found"
    exit 0
fi

if grep -q "$MARKER_START" "$RC_FILE"; then
    sed -i.bak "/$MARKER_START/,/$MARKER_END/d" "$RC_FILE"
fi

# Clean legacy quick-claude install too.
sed -i.bak '/# quick-claude/d' "$RC_FILE"
sed -i.bak '/alias .*quick-claude/d' "$RC_FILE"

echo "Uninstalled quick-agent aliases from $RC_FILE"
echo "Run 'source $RC_FILE' or restart your shell."
