#!/bin/bash
# Install OpenCode Drupal Agents configuration
# Usage: ./install.sh [target_dir]

set -euo pipefail

TARGET="${1:-${HOME}/.config/opencode}"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "Installing OpenCode Drupal Agents to: $TARGET"
echo ""

# Create target directory
mkdir -p "$TARGET"

# Copy agent definitions
if [ -d "$SCRIPT_DIR/agent" ]; then
    mkdir -p "$TARGET/agent"
    cp -v "$SCRIPT_DIR/agent/"*.md "$TARGET/agent/"
    echo "  Installed $(ls -1 "$SCRIPT_DIR/agent/"*.md | wc -l) agent definitions"
fi

# Copy rules
if [ -d "$SCRIPT_DIR/rules" ]; then
    mkdir -p "$TARGET/rules"
    cp -v "$SCRIPT_DIR/rules/"*.md "$TARGET/rules/"
    echo "  Installed $(ls -1 "$SCRIPT_DIR/rules/"*.md | wc -l) rules"
fi

# Copy skills
if [ -d "$SCRIPT_DIR/skills" ]; then
    mkdir -p "$TARGET/skills"
    for skill_dir in "$SCRIPT_DIR/skills"/*/; do
        skill_name=$(basename "$skill_dir")
        mkdir -p "$TARGET/skills/$skill_name"
        cp -v "$skill_dir"SKILL.md "$TARGET/skills/$skill_name/"
    done
    echo "  Installed $(ls -1d "$SCRIPT_DIR/skills"/*/ | wc -l) skills"
fi

# Copy orchestrator
if [ -f "$SCRIPT_DIR/CLAUDE.md" ]; then
    cp -v "$SCRIPT_DIR/CLAUDE.md" "$TARGET/"
    echo "  Installed CLAUDE.md orchestrator"
fi

# Copy config template if no config exists
if [ ! -f "$TARGET/opencode.json" ]; then
    if [ -f "$SCRIPT_DIR/opencode.json.example" ]; then
        cp "$SCRIPT_DIR/opencode.json.example" "$TARGET/opencode.json"
        echo "  Created opencode.json from template (review and customize!)"
    fi
else
    echo "  Skipping opencode.json (already exists)"
fi

# Copy notifier config template
if [ ! -f "$TARGET/opencode-notifier.json" ]; then
    if [ -f "$SCRIPT_DIR/opencode-notifier.json.example" ]; then
        cp "$SCRIPT_DIR/opencode-notifier.json.example" "$TARGET/opencode-notifier.json"
        echo "  Created opencode-notifier.json from template"
    fi
else
    echo "  Skipping opencode-notifier.json (already exists)"
fi

echo ""
echo "Installation complete!"
echo ""
echo "Next steps:"
echo "  1. Edit $TARGET/opencode.json to configure your providers and API keys"
echo "  2. Run 'opencode auth login' to authenticate"
echo "  3. Install ddev-opencode: ddev add-on get trebormc/ddev-opencode"
echo ""
