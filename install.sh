#!/bin/bash
# Install OpenCode Drupal Agents configuration
# Usage: ./install.sh [target_dir]
#
# Copies agent definitions, rules, skills, settings, and config to the OpenCode
# config directory. Model tokens in agent files are resolved using
# .env.agents values.

set -euo pipefail

TARGET="${1:-${HOME}/.config/opencode}"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "Installing OpenCode Drupal Agents to: $TARGET"
echo ""

# Load model aliases
if [ -f "$SCRIPT_DIR/.env.agents" ]; then
  set -a
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/.env.agents"
  set +a
  # Use OpenCode model values for standalone install
  export MODEL_SMART="$OC_MODEL_SMART"
  export MODEL_NORMAL="$OC_MODEL_NORMAL"
  export MODEL_CHEAP="$OC_MODEL_CHEAP"
  export MODEL_APPLIER="$OC_MODEL_APPLIER"
  echo "  Loaded model aliases from .env.agents"
else
  echo "  WARNING: .env.agents not found, using defaults"
  export MODEL_SMART="opencode/kimi-k2.5"
  export MODEL_NORMAL="opencode/minimax-m2.5"
  export MODEL_CHEAP="opencode/gpt-5-nano"
  export MODEL_APPLIER="opencode/gpt-5-nano"
fi

# Create target directory
mkdir -p "$TARGET"

# Copy agent definitions with model token substitution
if [ -d "$SCRIPT_DIR/.claude/agents" ]; then
    mkdir -p "$TARGET/agent"
    for src in "$SCRIPT_DIR/.claude/agents/"*.md; do
        [ -f "$src" ] || continue
        name=$(basename "$src")
        envsubst '${MODEL_SMART},${MODEL_NORMAL},${MODEL_CHEAP},${MODEL_APPLIER}' \
          < "$src" > "$TARGET/agent/$name"
        # Remove allowed_tools line (OpenCode doesn't need it)
        sed -i '/^allowed_tools:/d' "$TARGET/agent/$name"
    done
    echo "  Installed $(ls -1 "$SCRIPT_DIR/.claude/agents/"*.md | wc -l) agent definitions (model tokens resolved)"
fi

# Copy rules
if [ -d "$SCRIPT_DIR/.claude/rules" ]; then
    mkdir -p "$TARGET/rules"
    cp "$SCRIPT_DIR/.claude/rules/"*.md "$TARGET/rules/"
    echo "  Installed $(ls -1 "$SCRIPT_DIR/.claude/rules/"*.md | wc -l) rules"
fi

# Copy skills
if [ -d "$SCRIPT_DIR/.claude/skills" ]; then
    mkdir -p "$TARGET/skills"
    for skill_dir in "$SCRIPT_DIR/.claude/skills"/*/; do
        [ -d "$skill_dir" ] || continue
        skill_name=$(basename "$skill_dir")
        mkdir -p "$TARGET/skills/$skill_name"
        cp "$skill_dir"SKILL.md "$TARGET/skills/$skill_name/"
    done
    echo "  Installed $(ls -1d "$SCRIPT_DIR/.claude/skills"/*/ | wc -l) skills"
fi

# Copy settings.json
if [ -f "$SCRIPT_DIR/.claude/settings.json" ]; then
    mkdir -p "$TARGET/.claude"
    cp "$SCRIPT_DIR/.claude/settings.json" "$TARGET/.claude/settings.json"
    echo "  Installed .claude/settings.json"
fi

# Copy orchestrator
if [ -f "$SCRIPT_DIR/CLAUDE.md" ]; then
    cp "$SCRIPT_DIR/CLAUDE.md" "$TARGET/"
    echo "  Installed CLAUDE.md orchestrator"
fi

# Copy config template with model token substitution if no config exists
if [ ! -f "$TARGET/opencode.json" ]; then
    if [ -f "$SCRIPT_DIR/opencode.json.example" ]; then
        envsubst '${MODEL_SMART},${MODEL_NORMAL},${MODEL_CHEAP},${MODEL_APPLIER}' \
          < "$SCRIPT_DIR/opencode.json.example" > "$TARGET/opencode.json"
        echo "  Created opencode.json from template (review and customize!)"
    fi
else
    echo "  Skipping opencode.json (already exists)"
fi

# Copy notifier config if not present
if [ ! -f "$TARGET/opencode-notifier.json" ]; then
    if [ -f "$SCRIPT_DIR/opencode-notifier.json" ]; then
        cp "$SCRIPT_DIR/opencode-notifier.json" "$TARGET/opencode-notifier.json"
        echo "  Created opencode-notifier.json"
    fi
else
    echo "  Skipping opencode-notifier.json (already exists)"
fi

echo ""
echo "Installation complete!"
echo ""
echo "Next steps:"
echo "  1. Review $TARGET/opencode.json and customize providers if needed"
echo "  2. Run 'opencode auth login' to authenticate"
echo "  3. To change models, edit $SCRIPT_DIR/.env.agents and re-run this script"
echo ""
